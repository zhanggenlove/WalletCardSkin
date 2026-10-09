#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIR_CARD_ROOT="${AIR_CARD_ROOT:-${HOME}/Downloads/AirCard-main}"
AIR_CARD_BIN_ROOT="${AIR_CARD_BIN_ROOT:-${AIR_CARD_ROOT}/build}"
APP_ROOT="${PROJECT_ROOT}/build/WalletBloom.app"
CONTENTS_ROOT="${APP_ROOT}/Contents"
RESOURCES_ROOT="${CONTENTS_ROOT}/Resources"
BIN_ROOT="${RESOURCES_ROOT}/bin"

if [[ ! -x "${AIR_CARD_BIN_ROOT}/device_helper" || ! -x "${AIR_CARD_BIN_ROOT}/airtraffic_host" ]]; then
    printf '%s\n' "Missing AirCard helper binaries. Expected: ${AIR_CARD_BIN_ROOT}/device_helper" >&2
    exit 1
fi

env CLANG_MODULE_CACHE_PATH="/private/tmp/walletbloom-clang-cache" \
    SWIFT_MODULECACHE_PATH="/private/tmp/walletbloom-swift-cache" \
    swift build --disable-sandbox --configuration release

SPARKLE_FRAMEWORK="$(find "${PROJECT_ROOT}/.build/artifacts" -path '*macos*' -name 'Sparkle.framework' -maxdepth 6 | head -1)"
if [[ -z "${SPARKLE_FRAMEWORK}" ]]; then
    printf '%s\n' "Missing Sparkle.framework. Run: swift package resolve" >&2
    exit 1
fi

rm -rf "${APP_ROOT}"
mkdir -p "${CONTENTS_ROOT}/MacOS" "${CONTENTS_ROOT}/Frameworks" "${BIN_ROOT}"
cp "${PROJECT_ROOT}/Resources/Info.plist" "${CONTENTS_ROOT}/Info.plist"
cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${RESOURCES_ROOT}/AppIcon.icns"
mkdir -p "${RESOURCES_ROOT}/BuiltInSkins"
find "${PROJECT_ROOT}/Resources/BuiltInSkins" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \) -exec cp {} "${RESOURCES_ROOT}/BuiltInSkins/" \;
ditto "${SPARKLE_FRAMEWORK}" "${CONTENTS_ROOT}/Frameworks/Sparkle.framework"

# 内嵌独立 Python 运行时，让没有装 python3 的 Mac 也能刷入。默认 arm64 + x86_64 都带上。
# 放在 Resources 而非 Frameworks：Python 的 include、tcl 等子目录会让 codesign 误当成 bundle。
PYTHON_ARCHS=(${WB_PYTHON_ARCHS:-arm64 x86_64})
"${PROJECT_ROOT}/scripts/fetch_python.sh" "${PYTHON_ARCHS[@]}"
for arch in "${PYTHON_ARCHS[@]}"; do
    runtime_src="${PROJECT_ROOT}/build/python-runtime/${arch}/python"
    runtime_dst="${RESOURCES_ROOT}/python-${arch}"
    ditto "${runtime_src}" "${runtime_dst}"
    # 裁掉刷入用不到的部分（后端只用标准库，不用 Tk/头文件/静态库），减小体积并避免 codesign 误判 bundle。
    pylib="$(find "${runtime_dst}/lib" -maxdepth 1 -type d -name 'python3.*' | head -1)"
    if [[ -n "${pylib}" ]]; then
        rm -rf "${pylib}/test" "${pylib}/idlelib" "${pylib}/tkinter" "${pylib}/turtledemo" "${pylib}/ensurepip" "${pylib}/pydoc_data" "${pylib}/lib2to3" "${pylib}/config-"*
    fi
    rm -rf "${runtime_dst}/include" "${runtime_dst}/share"
    find "${runtime_dst}/lib" -maxdepth 1 \( -name 'tcl*' -o -name 'tk*' -o -name 'itcl*' -o -name 'Tktable*' -o -name 'libtcl*' -o -name 'libtk*' -o -name 'thread*' \) -exec rm -rf {} +
    find "${runtime_dst}" -type d -name '__pycache__' -prune -exec rm -rf {} +
done
cp "${PROJECT_ROOT}/.build/release/WalletBloom" "${CONTENTS_ROOT}/MacOS/WalletBloom"
cp "${AIR_CARD_BIN_ROOT}/device_helper" "${BIN_ROOT}/device_helper"
cp "${AIR_CARD_BIN_ROOT}/airtraffic_host" "${BIN_ROOT}/airtraffic_host"
cp "${AIR_CARD_ROOT}/aircard_backend.py" "${RESOURCES_ROOT}/aircard_backend.py"
cp "${AIR_CARD_ROOT}/apply_card_skin.py" "${RESOURCES_ROOT}/apply_card_skin.py"
cp "${AIR_CARD_ROOT}/card_assets.py" "${RESOURCES_ROOT}/card_assets.py"
cp "${AIR_CARD_ROOT}/aircard.py" "${RESOURCES_ROOT}/aircard.py"
chmod 755 "${CONTENTS_ROOT}/MacOS/WalletBloom" "${BIN_ROOT}/device_helper" "${BIN_ROOT}/airtraffic_host" "${RESOURCES_ROOT}/aircard_backend.py" "${RESOURCES_ROOT}/apply_card_skin.py"
find "${RESOURCES_ROOT}" -type d -name '__pycache__' -prune -exec rm -rf {} +
# Sparkle 与 Python 运行时由上游 ad-hoc 签名，这里只签名整个 bundle（不用 --deep，否则会把 Python 的子目录误当成 bundle）。
codesign --force --sign - "${APP_ROOT}"

printf 'Created %s\n' "${APP_ROOT}"
