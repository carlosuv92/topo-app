import Foundation

/// Modo sin interfaz para verificar el motor de limpieza.
/// Uso: topo --scan
enum CleanupCLI {
    static let version = "0.1.0"

    static func help() {
        print(
            """
            topo \(version) · limpieza y mantenimiento para macOS

            USO
              topo                 abre la interfaz
              topo --scan          informe de limpieza (solo lectura)
              topo --selftest      pruebas de la política de seguridad
              topo --permissions   diagnóstico de Acceso Total al Disco
              topo --help          esta ayuda
              topo --version       versión instalada

            VARIABLES
              TOPO_VERBOSE=1       detalle por archivo en --scan
              TOPO_SCAN_OUT=ruta   guarda el informe en un archivo
              TOPO_TAB=clean|software|optimize|analyze|status
            """
        )
    }

    static func permissions() {
        print("topo · diagnóstico de permisos")
        print(String(repeating: "─", count: 62))

        for probe in Permissions.probes {
            let url = Paths.expand(probe)
            let exists = FileManager.default.fileExists(atPath: url.path)
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
                print("  ✓ \(probe)  legible (exists=\(exists))")
            } catch let error as NSError {
                print("  ✗ \(probe)  \(error.domain) \(error.code) (exists=\(exists))")
            }
        }

        print(String(repeating: "─", count: 62))
        print(
            Permissions.hasFullDiskAccess
                ? "Acceso Total al Disco: activo"
                : "Acceso Total al Disco: no activo"
        )
    }

    static func run() {
        var lines: [String] = []
        func emit(_ line: String) {
            print(line)
            lines.append(line)
        }

        emit("topo · informe de limpieza")
        emit(String(repeating: "─", count: 62))

        var total: Int64 = 0
        var items = 0

        for category in CleanCategory.all {
            let found = CleanupEngine.scan(category)
            let size = found.reduce(Int64(0)) { $0 + $1.size }
            total += size
            items += found.count

            let name = category.id.padding(toLength: 24, withPad: " ", startingAt: 0)
            emit("\(name) \(pad(size.bytes, 12))  \(found.count) elem.")

            if ProcessInfo.processInfo.environment["TOPO_VERBOSE"] != nil {
                for item in found {
                    emit("    \(pad(item.size.bytes, 12))  \(item.url.path)")
                }
            }
        }

        emit(String(repeating: "─", count: 62))
        emit("TOTAL \(pad(total.bytes, 12))  \(items) elementos")

        if let output = ProcessInfo.processInfo.environment["TOPO_SCAN_OUT"] {
            try? lines.joined(separator: "\n").write(
                toFile: output,
                atomically: true,
                encoding: .utf8
            )
        }
    }

    private static func pad(_ value: String, _ width: Int) -> String {
        value.count >= width ? value : String(repeating: " ", count: width - value.count) + value
    }
}
