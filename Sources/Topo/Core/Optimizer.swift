import Foundation

struct OptimizeTask: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let requiresAdmin: Bool
    let command: String

    var badge: String {
        requiresAdmin ? "Requiere contraseña" : "Sin contraseña"
    }
}

struct OptimizeRun: Identifiable {
    let id = UUID()
    let taskID: String
    let title: String
    let success: Bool
    let output: String
}

enum Optimizer {

    private static let lsregister =
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    static let tasks: [OptimizeTask] = [
        OptimizeTask(
            id: "launchservices",
            title: "Reconstruir LaunchServices",
            detail: "Repara apps duplicadas en «Abrir con» y en el Finder.",
            symbol: "square.stack.3d.up",
            requiresAdmin: false,
            command: "\(lsregister) -kill -r -domain local -domain system -domain user"
        ),
        OptimizeTask(
            id: "dns",
            title: "Vaciar caché de DNS",
            detail: "Útil cuando un dominio resuelve a una IP antigua.",
            symbol: "network",
            requiresAdmin: true,
            command: "dscacheutil -flushcache && killall -HUP mDNSResponder"
        ),
        OptimizeTask(
            id: "purge",
            title: "Liberar memoria inactiva",
            detail: "Fuerza al sistema a recuperar RAM que ya nadie usa.",
            symbol: "memorychip",
            requiresAdmin: true,
            command: "/usr/bin/purge"
        ),
        OptimizeTask(
            id: "fontcache",
            title: "Limpiar caché de fuentes",
            detail: "Resuelve fuentes que se ven mal o desaparecen.",
            symbol: "textformat",
            requiresAdmin: true,
            command: "atsutil databases -remove"
        ),
        OptimizeTask(
            id: "spotlight",
            title: "Reindexar Spotlight",
            detail: "Reconstruye el índice de búsqueda del disco de arranque.",
            symbol: "magnifyingglass",
            requiresAdmin: true,
            command: "mdutil -E /"
        ),
        OptimizeTask(
            id: "logs",
            title: "Rotar registros del sistema",
            detail: "Compacta los logs antiguos del sistema.",
            symbol: "doc.plaintext",
            requiresAdmin: true,
            command: "newsyslog -v"
        ),
        OptimizeTask(
            id: "verify",
            title: "Verificar el disco",
            detail: "Comprobación de solo lectura del volumen de arranque.",
            symbol: "internaldrive",
            requiresAdmin: true,
            command: "diskutil verifyVolume /"
        )
    ]

    static func run(_ task: OptimizeTask) -> OptimizeRun {
        let result: ShellResult
        if task.requiresAdmin {
            result = Admin.run(task.command)
        } else {
            result = Shell.sh(task.command)
        }

        let output = result.combined
        let cancelled = output.contains("(-128)") || output.lowercased().contains("user canceled")

        return OptimizeRun(
            taskID: task.id,
            title: task.title,
            success: result.ok && !cancelled,
            output: output.isEmpty
                ? (result.ok ? "Listo." : "Sin salida.")
                : (cancelled ? "Cancelado por el usuario." : output)
        )
    }
}
