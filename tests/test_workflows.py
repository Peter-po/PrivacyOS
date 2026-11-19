import os
from pathlib import Path
import subprocess
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[1]
TARGET = "aosp_cf_x86_64_only_phone-aosp_current-userdebug"


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        temporary_dir = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_dir.cleanup)
        self.temp = Path(temporary_dir.name)
        self.aosp = self.temp / "AOSP source"
        build = self.aosp / "build"
        build.mkdir(parents=True)
        (build / "envsetup.sh").write_text(
            'lunch() { printf "target=%s\\n" "$1"; return "${LUNCH_STATUS:-0}"; }\n'
            'm() { printf "build=%s %s\\n" "$PWD" "$*"; return "${BUILD_STATUS:-0}"; }\n',
            encoding="utf-8",
        )
        adb = self.temp / "adb"
        adb.write_text(
            """#!/usr/bin/env bash
[[ $1 == -s && $2 == fixture-device ]] || exit 3
shift 2
case "$*" in
    'get-state') printf '%s\\n' "${ADB_STATE:-device}" ;;
    'shell getenforce') printf '%s\\r\\n' "${ADB_SELINUX:-Enforcing}" ;;
    'shell getprop ro.build.type') printf 'user\\n' ;;
    'shell getprop ro.debuggable') printf '0\\n' ;;
    'shell getprop ro.secure') printf '1\\n' ;;
    'shell getprop ro.boot.vbmeta.device_state') printf '%s\\n' "${ADB_LOCK:-locked}" ;;
    'shell getprop ro.boot.verifiedbootstate')
        [[ ${ADB_READ_STATUS:-0} == 0 ]] || exit 4
        printf '%s\\n' "${ADB_BOOT_STATE:-green}" ;;
    *) exit 5 ;;
esac
""",
            encoding="utf-8",
        )
        adb.chmod(0o755)

    def run_script(self, script, *args, **overrides):
        return subprocess.run(
            [PROJECT / script, *args],
            cwd=self.temp,
            env={**os.environ, "PATH": f"{self.temp}:{os.environ['PATH']}", **overrides},
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_build_runs_in_aosp_with_explicit_target_and_jobs(self):
        result = self.run_script("scripts/build.sh", self.aosp, TARGET, "3")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"target={TARGET}\n", result.stdout)
        self.assertIn(f"build={self.aosp} -j3\n", result.stdout)

    def test_missing_source_stops_the_build(self):
        result = self.run_script("scripts/build.sh", self.temp / "missing", TARGET)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("build/envsetup.sh", result.stderr)
        self.assertNotIn("target=", result.stdout)

    def test_invalid_parallelism_is_rejected(self):
        result = self.run_script("scripts/build.sh", self.aosp, TARGET, "0")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertNotIn("target=", result.stdout)

    def test_lunch_failure_stops_the_build(self):
        result = self.run_script("scripts/build.sh", self.aosp, TARGET, LUNCH_STATUS="7")
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertNotIn("build=", result.stdout)

    def test_build_failure_is_propagated(self):
        result = self.run_script("scripts/build.sh", self.aosp, TARGET, BUILD_STATUS="9")
        self.assertEqual(result.returncode, 9, result.stderr)

    def test_device_baseline_passes_for_expected_values(self):
        result = self.run_script("tests/device_security_baseline.sh", "fixture-device")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), 6)

    def test_device_baseline_rejects_permissive_selinux_and_unlocked_boot(self):
        result = self.run_script(
            "tests/device_security_baseline.sh", "fixture-device",
            ADB_SELINUX="Permissive", ADB_LOCK="unlocked",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("SELinux", result.stderr)
        self.assertIn("ro.boot.vbmeta.device_state", result.stderr)

    def test_custom_root_requires_opt_in(self):
        script = "tests/device_security_baseline.sh"
        result = self.run_script(script, "fixture-device", ADB_BOOT_STATE="yellow")
        self.assertEqual(result.returncode, 1)
        result = self.run_script(
            script, "fixture-device", "--allow-custom-root", ADB_BOOT_STATE="yellow",
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_device_read_failure_fails_the_baseline(self):
        result = self.run_script(
            "tests/device_security_baseline.sh", "fixture-device", ADB_READ_STATUS="4",
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("ro.boot.verifiedbootstate", result.stderr)

    def test_offline_device_fails_before_running_checks(self):
        result = self.run_script(
            "tests/device_security_baseline.sh", "fixture-device", ADB_STATE="offline",
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
