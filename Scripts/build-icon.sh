#!/bin/bash
# Genera Assets/AppIcon.icns a partir del icono vectorial (CoreGraphics).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ICONSET="$ROOT/.build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$ROOT/Assets"

echo "▸ Dibujando icono base 1024…"
swift "$ROOT/Scripts/make-icon.swift" 1024 "$ROOT/Assets/icon-1024.png"

echo "▸ Generando tamaños…"
# mkicon <tamaño> <nombre-destino>
mkicon() {
  swift "$ROOT/Scripts/make-icon.swift" "$1" "$ICONSET/$2"
}

mkicon 16   icon_16x16.png
mkicon 32   icon_16x16@2x.png
mkicon 32   icon_32x32.png
mkicon 64   icon_32x32@2x.png
mkicon 128  icon_128x128.png
mkicon 256  icon_128x128@2x.png
mkicon 256  icon_256x256.png
mkicon 512  icon_256x256@2x.png
mkicon 512  icon_512x512.png
mkicon 1024 icon_512x512@2x.png

echo "▸ Empaquetando .icns"
iconutil -c icns "$ICONSET" -o "$ROOT/Assets/AppIcon.icns"

echo "▸ Listo: Assets/AppIcon.icns ($(du -h "$ROOT/Assets/AppIcon.icns" | cut -f1))"
