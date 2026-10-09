#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIR_CARD_ROOT="${AIR_CARD_ROOT:-/Users/zhanggen/Downloads/AirCard-main}"
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
cp "${PROJECT_ROOT}/.build/release/WalletBloom" "${CONTENTS_ROOT}/MacOS/WalletBloom"
cp "${AIR_CARD_BIN_ROOT}/device_helper" "${BIN_ROOT}/device_helper"
cp "${AIR_CARD_BIN_ROOT}/airtraffic_host" "${BIN_ROOT}/airtraffic_host"
cp "${AIR_CARD_ROOT}/aircard_backend.py" "${RESOURCES_ROOT}/aircard_backend.py"
cp "${AIR_CARD_ROOT}/apply_card_skin.py" "${RESOURCES_ROOT}/apply_card_skin.py"
cp "${AIR_CARD_ROOT}/card_assets.py" "${RESOURCES_ROOT}/card_assets.py"
cp "${AIR_CARD_ROOT}/aircard.py" "${RESOURCES_ROOT}/aircard.py"
chmod 755 "${CONTENTS_ROOT}/MacOS/WalletBloom" "${BIN_ROOT}/device_helper" "${BIN_ROOT}/airtraffic_host" "${RESOURCES_ROOT}/aircard_backend.py" "${RESOURCES_ROOT}/apply_card_skin.py"
find "${RESOURCES_ROOT}" -type d -name '__pycache__' -prune -exec rm -rf {} +
codesign --force --deep --sign - "${APP_ROOT}"

printf 'Created %s\n' "${APP_ROOT}"
