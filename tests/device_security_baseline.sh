#!/usr/bin/env bash
set -u

usage() {
    printf '用法：%s DEVICE_SERIAL [--allow-custom-root]\n' "$0"
}

if [[ $# -eq 1 && $1 == --help ]]; then
    usage
    exit 0
fi
if [[ $# -lt 1 || $# -gt 2 || -z $1 || $1 == -* || ( $# -eq 2 && $2 != --allow-custom-root ) ]]; then
    usage >&2
    exit 2
fi

if ! command -v adb >/dev/null 2>&1; then
    printf '错误：需要 Android Platform Tools 中的 adb。\n' >&2
    exit 1
fi
adb_device=(adb -s "$1")
if ! state=$("${adb_device[@]}" get-state) || [[ $state != device ]]; then
    printf '错误：设备 %s 尚未连接或授权。\n' "$1" >&2
    exit 1
fi

failures=0
check_value() {
    local label=$1 expected=$2 alternative=$3 actual
    shift 3
    if ! actual=$("${adb_device[@]}" shell "$@"); then
        printf '失败：%s 读取失败。\n' "$label" >&2
        ((failures += 1))
        return
    fi
    actual=${actual%$'\r'}
    if [[ $actual == "$expected" || ( -n $alternative && $actual == "$alternative" ) ]]; then
        printf '通过：%s = %s\n' "$label" "$actual"
    else
        printf '失败：%s 实际值为 %q，预期 %s。\n' \
            "$label" "$actual" "$expected${alternative:+ 或 $alternative}" >&2
        ((failures += 1))
    fi
}

custom_root_state=
if [[ ${2:-} == --allow-custom-root ]]; then
    custom_root_state=yellow
fi
check_value SELinux Enforcing '' getenforce
check_value ro.build.type user '' getprop ro.build.type
check_value ro.debuggable 0 '' getprop ro.debuggable
check_value ro.secure 1 '' getprop ro.secure
check_value ro.boot.vbmeta.device_state locked '' getprop ro.boot.vbmeta.device_state
check_value ro.boot.verifiedbootstate green "$custom_root_state" getprop ro.boot.verifiedbootstate

(( failures == 0 ))
