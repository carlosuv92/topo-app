# Topo

Utilidad nativa de mantenimiento para macOS, hecha con SwiftUI + Swift Package
Manager, sin dependencias externas.

<p align="center">
  <img src="Assets/icon-1024.png" width="150" alt="Icono de Topo">
</p>

```
topo/
├── Package.swift
├── Makefile
├── Assets/            icono (fuente PNG y .icns generado)
├── Scripts/           bundle, icono, instalador y .pkg
└── Sources/Topo/
    ├── App/           punto de entrada, barra de menús
    ├── Core/          motores: limpieza, desinstalación, disco, métricas, permisos
    ├── Models/        categorías y tipos
    └── Views/         interfaz
```

## Instalar

La forma más rápida es el instalador: instala **la app y el comando `topo`**
en una sola pasada.

```bash
make pkg                      # genera dist/topo-0.1.0.pkg
open dist/topo-0.1.0.pkg      # doble clic → Instalar
```

El paquete coloca:

| Ruta | Qué es |
| --- | --- |
| `/Applications/Topo.app` | la aplicación |
| `/usr/local/bin/topo` | enlace al binario, para usar el CLI desde Terminal |

Alternativa sin `.pkg` (desde el repo):

```bash
./Scripts/install.sh           # copia a /Applications y enlaza el comando
```

## Compilar y ejecutar

```bash
make                 # release + dist/Topo.app
make run             # compila y abre
make icon            # regenera Assets/AppIcon.icns
make test            # compila y ejecuta --selftest
make clean           # borra .build y dist
```

Equivalente manual:

```bash
swift build            # compilar
./Scripts/bundle.sh    # generar dist/Topo.app
open dist/Topo.app
```

Para desarrollo rápido también sirve `swift run`, aunque sin bundle la app
aparece sin nombre ni icono propio. El bundle es la forma recomendada.

### Modo sin interfaz

```bash
topo --scan           # informe de limpieza (solo lectura)
topo --selftest       # pruebas de la política de seguridad
topo --permissions    # diagnóstico de Acceso Total al Disco
topo --help           # ayuda
topo --version        # versión

TOPO_VERBOSE=1 topo --scan             # detalle por archivo
TOPO_SCAN_OUT=/tmp/informe.txt topo --scan
```

### Abrir en una pestaña concreta

Útil para desarrollo y capturas. Funciona solo si la app **no** está corriendo:

```bash
open dist/Topo.app --env TOPO_TAB=status
# valores: clean | software | optimize | analyze | status
```

## Qué hace

| Pestaña | Función |
| --- | --- |
| **Limpieza** | Escanea cachés de apps, logs, informes de fallos, estados guardados, cachés de desarrollo (Xcode, npm, Gradle, Homebrew…), navegadores y `/Library/Caches`. |
| **Aplicaciones** | Lista las apps instaladas, calcula su tamaño, encuentra los restos fuera del paquete y desinstala mandando todo a la Papelera. |
| **Optimizar** | LaunchServices, caché de DNS, purga de memoria, caché de fuentes, reindexado de Spotlight, rotación de logs, verificación de disco. |
| **Disco** | Explorador de tamaños por carpeta + buscador de archivos de más de 200 MB. |
| **Estado** | CPU por núcleo, memoria, disco, red, batería, carga media y procesos con más consumo, en vivo. Barra de menús incluida. |

### Revisión antes de borrar

El botón principal de **Limpieza** es *Revisar y limpiar*, no *Limpiar*.
Abre una hoja con:

- el total exacto y cuántos elementos son,
- cada archivo agrupado por categoría, con su ruta completa y su tamaño,
- una advertencia de que la limpieza de cachés es permanente (no pasa por la Papelera).

Nada se elimina hasta pulsar *Eliminar*. Las desinstalaciones de apps sí van a
la Papelera y se pueden recuperar.

## Permisos

Topo arranca sin pedir nada porque solo toca cachés y registros del usuario.
Hay dos permisos que se gestionan al estilo macOS:

1. **Acceso Total al Disco (opcional)**. macOS protege `~/Library/Safari`,
   `~/Library/Mail`, `~/Library/Messages` y parte de `~/Library/Containers`.
   Sin este permiso la app funciona igual, pero omite esas zonas al buscar
   restos de aplicaciones. La primera vez se muestra una bienvenida con el
   botón *Abrir Ajustes*, y mientras falte el permiso queda un aviso en
   **Limpieza** y **Aplicaciones**. También puedes volver a verlo en
   *Ayuda → Bienvenida de Topo* (⇧⌘/).
2. **Automatización / Apple Events**. Solo se pide al ejecutar tareas que
   necesitan AppleScript (`osascript … with administrator privileges`), con el
   diálogo nativo de macOS. La descripción está declarada en el `Info.plist`
   del bundle (`NSAppleEventsUsageDescription`).

Comprobar el estado real desde Terminal:

```bash
topo --permissions
```

## Seguridad

Todas las operaciones de borrado pasan por `Core/SafetyPolicy.swift`:

1. **Lista blanca**: un elemento solo se puede borrar si vive estrictamente
   dentro de una raíz declarada por su propia categoría (o es exactamente esa
   raíz, en categorías de un solo directorio como la caché de npm).
2. **Lista negra**: `/System`, `/usr`, `/Library/Extensions`, `~/Documents`,
   `~/Desktop`, `~/Library/Preferences`, `~/Library/Keychains` y similares
   nunca se tocan.
3. **Sin symlinks ni alias**: se rechazan antes de borrar, y la ruta se
   revalida después de resolver enlaces del padre.
4. Las categorías con datos que no se regeneran (Xcode Archives, Maven,
   Papelera, `/Library/Caches`) llegan **desmarcadas** y marcadas como
   «revisar».
5. Solo se escribe con contraseña cuando la tarea es realmente del sistema,
   mediante el diálogo nativo de macOS.

Las reglas están cubiertas por pruebas ejecutables: `--selftest` (8 casos).

## Icono

El icono es un topo saliendo de su madriguera, dibujado con CoreGraphics en
`Scripts/make-icon.swift` (degradado + personaje) y empaquetado con
`Scripts/build-icon.sh`. No depende de ninguna imagen externa.

```bash
make icon        # Assets/icon-1024.png → Assets/AppIcon.icns
```

Detalle importante: a partir de macOS 26 el sistema aplica su propia máscara
squircle. Por eso el lienzo se dibuja como un **cuadrado opaco** y sin
transparencia en las esquinas; si se dejan píxeles transparentes, macOS coloca
el icono sobre una placa gris. En macOS 14–15, que no aplican esa máscara, el
icono se verá cuadrado.

## Requisitos

- macOS 14 o superior.
- Swift 5.9+ (basta con Command Line Tools; no hace falta Xcode).
- **Nota sobre macOS 27**: `@State` pasó a ser una macro y su plugin
  (`SwiftUIMacros`) solo viene con Xcode completo. Este proyecto evita `@State`
  y usa `@StateObject` con modelos pequeños, así compila con Command Line Tools.

## Distribución

- El `.pkg` no está firmado ni notarizado todavía: al abrirlo en otro Mac,
  macOS puede pedir confirmación (clic derecho → Abrir).
- Con una cuenta de Developer ID, el paso pendiente es
  `productsign` + `notarytool submit`.
- La app se firma ad-hoc en `Scripts/bundle.sh` para que macOS mantenga
  estable la identidad entre ejecuciones.

## Pendiente / ideas

- Control de ventiladores (requiere acceso a AppleSMC / IOKit privado).
- Lectura de temperatura del SoC.
- Treemap visual en la pestaña Disco.
- Historial persistente de espacio liberado.
- Firma con Developer ID y notarización.
- Sonido/animación del topo al terminar una limpieza.

## Licencia

MIT. Ver [`LICENSE`](LICENSE).
