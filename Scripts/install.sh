#!/bin/bash
# Instala Topo en /Applications y deja el comando `topo` disponible.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Topo"
CLI_NAME="topo"
EXEC_NAME="Topo"

APP_SRC="$ROOT/dist/$APP_NAME.app"
APP_DEST="/Applications/$APP_NAME.app"

if [[ ! -d "$APP_SRC" ]]; then
  echo "▸ No existe $APP_SRC, generándolo…"
  "$ROOT/Scripts/bundle.sh"
fi

echo "▸ Cerrando instancias abiertas…"
osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
pkill -f "$APP_NAME.app/Contents/MacOS" >/dev/null 2>&1 || true
sleep 1

echo "▸ Instalando en $APP_DEST"
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"
xattr -dr com.apple.quarantine "$APP_DEST" >/dev/null 2>&1 || true

echo "▸ Enlazando el comando «${CLI_NAME}»"
BIN="$APP_DEST/Contents/MacOS/$EXEC_NAME"

if [[ -w /usr/local/bin ]]; then
  CLI_LINK="/usr/local/bin/$CLI_NAME"
  ln -sfn "$BIN" "$CLI_LINK"
elif [[ -d /opt/homebrew/bin && -w /opt/homebrew/bin ]]; then
  CLI_LINK="/opt/homebrew/bin/$CLI_NAME"
  ln -sfn "$BIN" "$CLI_LINK"
else
  echo "  (se necesitan permisos de administrador para /usr/local/bin)"
  sudo mkdir -p /usr/local/bin
  CLI_LINK="/usr/local/bin/$CLI_NAME"
  sudo ln -sfn "$BIN" "$CLI_LINK"
fi

# Limpieza de una instalación anterior con otro nombre, si existía.
rm -rf "/Applications/moleuv.app" 2>/dev/null || true
rm -f "/usr/local/bin/moleuv" "/opt/homebrew/bin/moleuv" 2>/dev/null || true

echo
echo "✓ Topo instalado"
echo "  App:     $APP_DEST"
echo "  Comando: $CLI_LINK"
echo
echo "  Pruébalo:"
echo "    open \"$APP_DEST\""
echo "    topo --scan"
echo
echo "  Si macOS bloquea la app la primera vez: clic derecho → Abrir."
echo "  Para analizar Correo/Safari, concede Acceso Total al Disco"
echo "  (Ajustes del Sistema → Privacidad y seguridad)."
