#!/usr/bin/env bash
# ==============================================================================
# build_dmg.sh - Build Universal macOS DMG for LockedIn
# Generates a universal Mach-O binary (arm64 + x86_64), bundles LockedIn.app,
# creates AppIcon.icns, applies ad-hoc codesigning, and packages into a DMG.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_NAME="LockedIn"
DMG_NAME="LockedIn-Universal.dmg"
BUILD_DIR="${ROOT_DIR}/.build"
TEMP_DIR="$(mktemp -d /tmp/lockedin_build.XXXXXX)"
APP_DIR="${TEMP_DIR}/${APP_NAME}.app"
DMG_ROOT="${TEMP_DIR}/dmg_root"

echo "==> Building ${APP_NAME} for Apple Silicon (arm64)..."
swift build -c release --triple arm64-apple-macosx13.0

echo "==> Building ${APP_NAME} for Intel (x86_64)..."
swift build -c release --triple x86_64-apple-macosx13.0

echo "==> Constructing ${APP_NAME}.app bundle structure..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

echo "==> Creating universal binary with lipo..."
lipo -create \
  "${BUILD_DIR}/arm64-apple-macosx/release/${APP_NAME}" \
  "${BUILD_DIR}/x86_64-apple-macosx/release/${APP_NAME}" \
  -output "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

echo "==> Copying Info.plist and PkgInfo..."
cp "${ROOT_DIR}/LockedIn/Info.plist" "${APP_DIR}/Contents/Info.plist"
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

echo "==> Generating AppIcon.icns..."
ICONSET_DIR="${TEMP_DIR}/${APP_NAME}.iconset"
mkdir -p "${ICONSET_DIR}"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_16x16.png" "${ICONSET_DIR}/icon_16x16.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png" "${ICONSET_DIR}/icon_16x16@2x.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_32x32.png" "${ICONSET_DIR}/icon_32x32.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png" "${ICONSET_DIR}/icon_32x32@2x.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" "${ICONSET_DIR}/icon_128x128.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" "${ICONSET_DIR}/icon_128x128@2x.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" "${ICONSET_DIR}/icon_256x256.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" "${ICONSET_DIR}/icon_256x256@2x.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" "${ICONSET_DIR}/icon_512x512.png"
cp "${ROOT_DIR}/LockedIn/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" "${ICONSET_DIR}/icon_512x512@2x.png"

iconutil -c icns "${ICONSET_DIR}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"

echo "==> Copying asset bundles..."
if [ -d "${BUILD_DIR}/arm64-apple-macosx/release/LockedIn_LockedIn.bundle" ]; then
  cp -R "${BUILD_DIR}/arm64-apple-macosx/release/LockedIn_LockedIn.bundle" "${APP_DIR}/Contents/Resources/"
fi

echo "==> Applying ad-hoc codesign..."
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Preparing DMG staging root..."
mkdir -p "${DMG_ROOT}"
cp -R "${APP_DIR}" "${DMG_ROOT}/"
ln -s /Applications "${DMG_ROOT}/Applications"

echo "==> Creating compressed disk image (${DMG_NAME})..."
rm -f "${ROOT_DIR}/${DMG_NAME}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_ROOT}" -ov -format UDZO "${ROOT_DIR}/${DMG_NAME}"

echo "==> Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

echo "==> Universal DMG built successfully: ${ROOT_DIR}/${DMG_NAME}"
ls -lh "${ROOT_DIR}/${DMG_NAME}"
lipo -info "${ROOT_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || file "${BUILD_DIR}/arm64-apple-macosx/release/${APP_NAME}"
