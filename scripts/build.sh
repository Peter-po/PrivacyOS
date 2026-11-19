#!/usr/bin/env bash

usage() {
    printf '用法：%s AOSP源码目录 LUNCH目标 [并行任务数]\n' "$0"
}

if [[ $# -eq 1 && $1 == --help ]]; then
    usage
    exit 0
fi
if [[ $# -lt 2 || $# -gt 3 || ! $2 =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
    usage >&2
    exit 2
fi

jobs=${3:-$(nproc)}
if [[ ! $jobs =~ ^[1-9][0-9]*$ ]]; then
    printf '错误：并行任务数必须为正整数。\n' >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit
"$script_dir/check_environment.sh" "$1" || exit
cd -- "$1" || exit

source build/envsetup.sh || exit
lunch "$2" || exit
m -j"$jobs"
