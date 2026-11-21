#!/bin/bash
# Compila Topo y ensambla un .app ejecutable en ./dist
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="Topo"          # Topo.app
EXEC_NAME="Topo"         # Topo.app/Contents/MacOS/Topo
BUILD_DIR="$ROOT/.build/$CONFIG"
DIST="$ROOT/dist/$APP_NAME.app"

echo "▸ Compilando ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$BUILD_DIR/$EXEC_NAME"
if [[ ! -f "$BIN" ]]; then
  echo "No se encontró el binario en $BIN" >&2
  exit 1
fi

echo "▸ Ensamblando $DIST"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN" "$DIST/Contents/MacOS/$EXEC_NAME"

ICON="$ROOT/Assets/AppIcon.icns"
if [[ -f "$ICON" ]]; then
  cp "$ICON" "$DIST/Contents/Resources/AppIcon.icns"
else
  echo "  (sin icono: ejecuta ./Scripts/build-icon.sh para generarlo)"
fi

cat > "$DIST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Topo</string>
    <key>CFBundleDisplayName</key>
    <string>Topo</string>
    <key>CFBundleExecutable</key>
    <string>$EXEC_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.urciacorp.topo</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Topo usa AppleScript para ejecutar tareas de mantenimiento del sistema con tu autorización.</string>
    <key>NSHumanReadableCopyright</key>
    <string>UrciaCorp</string>
</dict>
</plist>
PLIST

# Touch the bundle so Finder/LaunchServices picks up the new icon.
touch "$DIST"

# Ad-hoc signature so macOS keeps sensors/permissions stable between runs.
codesign --force --deep --sign - "$DIST" >/dev/null 2>&1 || true

echo "▸ Listo: $DIST"
echo "  Abrir con: open \"$DIST\""
