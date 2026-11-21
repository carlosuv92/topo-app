#!/bin/bash
# Construye un instalador de macOS (.pkg) que instala:
#   /Applications/Topo.app
#   /usr/local/bin/topo  ->  enlace al binario de la app
#
# Uso: ./Scripts/build-pkg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Topo"
CLI_NAME="topo"
EXEC_NAME="Topo"
VERSION="0.1.0"
IDENTIFIER="com.urciacorp.topo"
APP_SRC="$ROOT/dist/$APP_NAME.app"
WORK="$ROOT/.build/pkg"
PKGROOT="$WORK/root"
COMPONENT="$WORK/$CLI_NAME-component.pkg"
DIST="$ROOT/dist"
OUT="$DIST/$CLI_NAME-$VERSION.pkg"

# 1. Asegurar que la app está compilada y ensamblada.
if [[ ! -d "$APP_SRC" ]]; then
  echo "▸ No existe $APP_SRC, generándolo…"
  "$ROOT/Scripts/bundle.sh"
fi

# 2. Preparar el payload.
echo "▸ Preparando payload…"
rm -rf "$WORK"
mkdir -p "$PKGROOT/Applications" "$PKGROOT/usr/local/bin"

cp -R "$APP_SRC" "$PKGROOT/Applications/$APP_NAME.app"

# Limpiar atributos extendidos y los archivos AppleDouble (._*) que genera
# pkgbuild al encontrarlos; el payload queda limpio.
xattr -cr "$PKGROOT" >/dev/null 2>&1 || true
find "$PKGROOT" -name '._*' -delete 2>/dev/null || true

# El CLI es el mismo binario de la app: un enlace evita duplicarlo y mantiene
# una única versión instalada. Ruta absoluta para que funcione desde cualquier cwd.
ln -s "/Applications/$APP_NAME.app/Contents/MacOS/$EXEC_NAME" \
      "$PKGROOT/usr/local/bin/$CLI_NAME"

# 3. Component package (sin GUI todavía).
echo "▸ Construyendo componente…"
pkgbuild \
  --root "$PKGROOT" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location "/" \
  --ownership recommended \
  --filter '\._[^/]*$' \
  --filter '\.DS_Store$' \
  "$COMPONENT" >/dev/null

# 4. Recursos del instalador: bienvenida y README visibles en Installer.app.
RES="$WORK/resources"
mkdir -p "$RES"
cat > "$RES/welcome.html" <<HTML
<html><body style="font-family:-apple-system;font-size:13px;color:#222">
<h2 style="margin:0 0 8px">Topo $VERSION</h2>
<p>Limpieza y mantenimiento para macOS.</p>
<p>Este instalador coloca:</p>
<ul>
  <li><b>Topo.app</b> en <code>/Applications</code></li>
  <li>el comando <b>topo</b> en <code>/usr/local/bin</code></li>
</ul>
<p>Al terminar puedes abrir la app desde Launchpad, Spotlight o ejecutando
<code>topo</code> en Terminal.</p>
</body></html>
HTML

cat > "$RES/readme.html" <<HTML
<html><body style="font-family:-apple-system;font-size:12px;color:#333">
<h3 style="margin:0 0 6px">Primeros pasos</h3>
<p>Abre la app y espera el primer escaneo. Todo se puede revisar antes de
borrar: Topo muestra la lista exacta de archivos y su tamaño.</p>

<h3 style="margin:12px 0 6px">Comando de terminal</h3>
<pre style="background:#f2f2f2;padding:8px;border-radius:6px;font-size:11px">topo --scan       informe de limpieza
topo --selftest   pruebas de seguridad
topo --help       ayuda</pre>

<h3 style="margin:12px 0 6px">Permisos</h3>
<p>Topo funciona sin permisos especiales. Para analizar zonas protegidas
por macOS (Correo, Safari, Mensajes) concede <b>Acceso Total al Disco</b> en
Ajustes del Sistema → Privacidad y seguridad.</p>
</body></html>
HTML

# 5. Producto final: distribución con la versión y los recursos.
echo "▸ Construyendo instalador…"
cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Topo $VERSION</title>
    <organization>$IDENTIFIER</organization>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_localSystem="true" enable_currentUserHome="false" enable_anywhere="false"/>
    <welcome file="welcome.html" mime-type="text/html"/>
    <readme file="readme.html" mime-type="text/html"/>
    <pkg-ref id="$IDENTIFIER"/>
    <choices-outline>
        <line choice="default"/>
    </choices-outline>
    <choice id="default" visible="false">
        <pkg-ref id="$IDENTIFIER"/>
    </choice>
    <pkg-ref id="$IDENTIFIER" version="$VERSION" onConclusion="none">$CLI_NAME-component.pkg</pkg-ref>
</installer-gui-script>
XML

mkdir -p "$DIST"
rm -f "$OUT"
productbuild \
  --distribution "$WORK/distribution.xml" \
  --resources "$RES" \
  --package-path "$WORK" \
  "$OUT" >/dev/null

echo
echo "✓ Instalador listo: $OUT"
echo "  Tamaño: $(du -h "$OUT" | cut -f1)"
echo
echo "  Instalar con doble clic o:"
echo "    sudo installer -pkg \"$OUT\" -target /"
