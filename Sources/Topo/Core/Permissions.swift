import AppKit
import Foundation

/// Detección y guía de permisos del sistema.
///
/// topo funciona sin permisos especiales gracias a que solo toca cachés y
/// registros. Aun así, hay dos áreas que macOS protege y que solo se pueden
/// analizar con Acceso Total al Disco:
///
/// - `~/Library/Mail`, `~/Library/Safari`, `~/Library/Messages`
/// - buena parte de `~/Library/Containers` (restos de apps)
enum Permissions {

    static let probes = [
        "~/Library/Safari",
        "~/Library/Mail",
        "~/Library/Messages"
    ]

    /// `true` cuando podemos leer al menos una carpeta protegida por TCC.
    /// Si todo falla por permisos, asumimos que no hay Acceso Total al Disco.
    static var hasFullDiskAccess: Bool {
        var denied = false

        for probe in probes {
            let url = Paths.expand(probe)
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
                return true
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain,
                   error.code == NSFileReadNoPermissionError {
                    denied = true
                } else if error.domain == NSPOSIXErrorDomain,
                          error.code == Int(EPERM) {
                    denied = true
                }
            }
        }

        return !denied
    }

    static func openFullDiskAccessSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        )
        if let url {
            NSWorkspace.shared.open(url)
        }
    }

    static func openLoginItemsSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LoginItems"
        )
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}

@MainActor
final class PermissionsModel: ObservableObject {
    @Published var hasFullDiskAccess: Bool = Permissions.hasFullDiskAccess
    @Published var justRechecked = false

    func refresh() {
        hasFullDiskAccess = Permissions.hasFullDiskAccess
        justRechecked = true
    }
}
