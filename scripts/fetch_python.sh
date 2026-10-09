#!/usr/bin/env bash
# 下载独立的 Python 运行时（python-build-standalone），供 package_app.sh 嵌入 App。
# 下载结果缓存在 build/python-runtime/<arch>，已存在则跳过。
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 固定版本，保证每次打包得到一致的运行时。升级时同时改这两行。
PY_RELEASE="20261003"
PY_VERSION="3.12.15"
DEST_ROOT="${PROJECT_ROOT}/build/python-runtime"
BASE_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PY_RELEASE}"

# 脚本参数即要下载的架构；默认两种都下，保证 Intel 与 Apple Silicon 都能用。
ARCHES=("$@")
if [[ ${#ARCHES[@]} -eq 0 ]]; then
    ARCHES=(arm64 x86_64)
fi

for arch in "${ARCHES[@]}"; do
    case "${arch}" in
        arm64)  triple="aarch64-apple-darwin" ;;
        x86_64) triple="x86_64-apple-darwin" ;;
        *) printf 'Unknown arch: %s\n' "${arch}" >&2; exit 1 ;;
    esac

    dest="${DEST_ROOT}/${arch}"
    if [[ -x "${dest}/python/bin/python3" ]]; then
        printf 'Python %s runtime already present: %s\n' "${arch}" "${dest}"
        continue
    fi

    asset="cpython-${PY_VERSION}+${PY_RELEASE}-${triple}-install_only.tar.gz"
    printf 'Downloading %s ...\n' "${asset}"
    rm -rf "${dest}"
    mkdir -p "${dest}"
    curl -fL --retry 3 "${BASE_URL}/${asset}" -o "${dest}/python.tar.gz"
    # install_only 包解压后是一个 python/ 目录（含 bin/lib）。
    tar -xzf "${dest}/python.tar.gz" -C "${dest}"
    rm -f "${dest}/python.tar.gz"
    "${dest}/python/bin/python3" -c 'import sys; print("Python runtime ready:", sys.version.split()[0])'
done
