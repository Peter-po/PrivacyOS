#!/usr/bin/env bash
set -u

usage() {
    printf '用法：%s AOSP源码目录\n' "$0"
}

if [[ $# -eq 1 && $1 == --help ]]; then
    usage
    exit 0
fi
if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

failed=0
if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    printf '错误：此构建入口需要 x86_64 Linux。\n' >&2
    failed=1
fi

for command in git python3; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf '错误：缺少 %s。\n' "$command" >&2
        failed=1
    fi
done

if ! command -v repo >/dev/null 2>&1; then
    printf '提示：缺少 repo，同步或刷新 AOSP 源码时需要安装。\n' >&2
fi

if [[ ! -r $1/build/envsetup.sh ]]; then
    printf '错误：找不到可读的 %s/build/envsetup.sh，请先同步 AOSP 源码。\n' "$1" >&2
    failed=1
fi

disk_path=$1
if [[ -n ${OUT_DIR:-} ]]; then
    disk_path=$OUT_DIR
    if [[ $disk_path != /* ]]; then
        disk_path=$1/$disk_path
    fi
fi
while [[ ! -d $disk_path && $disk_path != . && $disk_path != / ]]; do
    disk_path=$(dirname -- "$disk_path")
done
if available_kib=$(df -Pk -- "$disk_path" | awk 'NR == 2 {print $4}') && [[ $available_kib =~ ^[0-9]+$ ]]; then
    if (( available_kib < 400 * 1000 * 1000 * 1000 / 1024 )); then
        printf '提示：%s 所在文件系统可用空间低于 AOSP 建议的 400 GB。\n' "$disk_path" >&2
    fi
fi

if [[ -r /proc/meminfo ]]; then
    memory_kib=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    if [[ $memory_kib =~ ^[0-9]+$ ]] && (( memory_kib < 64 * 1024 * 1024 )); then
        printf '提示：主机内存低于 AOSP 建议的 64 GiB。\n' >&2
    fi
fi

if (( failed )); then
    exit 1
fi
printf 'AOSP 源码入口和基础主机工具检查通过。\n'
