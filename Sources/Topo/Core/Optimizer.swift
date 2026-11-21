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

    /// Usa rutas absolutas: una app lanzada desde el Finder no hereda el PATH
    /// del usuario. Si alguna herramienta no existe en esta versión de macOS,
    /// la tarea simplemente no se muestra en lugar de fallar.
    private static func firstExisting(_ candidates: [String]) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static let tasks: [OptimizeTask] = buildTasks()

    private static func buildTasks() -> [OptimizeTask] {
        var list: [OptimizeTask] = []

        if firstExisting([lsregister]) != nil {
            list.append(
                OptimizeTask(
                    id: "launchservices",
                    title: "Reconstruir LaunchServices",
                    detail: "Repara apps duplicadas en «Abrir con» y en el Finder.",
                    symbol: "square.stack.3d.up",
                    requiresAdmin: false,
                    command: "\(lsregister) -kill -r -domain local -domain system -domain user"
                )
            )
        }

        if let dscacheutil = firstExisting(["/usr/bin/dscacheutil"]),
           let killall = firstExisting(["/usr/bin/killall"]) {
            list.append(
                OptimizeTask(
                    id: "dns",
                    title: "Vaciar caché de DNS",
                    detail: "Útil cuando un dominio resuelve a una IP antigua.",
                    symbol: "network",
                    requiresAdmin: true,
                    command: "\(dscacheutil) -flushcache && \(killall) -HUP mDNSResponder"
                )
            )
        }

        // Apple movió `purge` de /usr/bin a /usr/sbin en versiones recientes.
        if let purge = firstExisting(["/usr/bin/purge", "/usr/sbin/purge"]) {
            list.append(
                OptimizeTask(
                    id: "purge",
                    title: "Liberar memoria inactiva",
                    detail: "Fuerza al sistema a recuperar RAM que ya nadie usa.",
                    symbol: "memorychip",
                    requiresAdmin: true,
                    command: purge
                )
            )
        }

        if let atsutil = firstExisting(["/usr/bin/atsutil"]) {
            list.append(
                OptimizeTask(
                    id: "fontcache",
                    title: "Limpiar caché de fuentes",
                    detail: "Resuelve fuentes que se ven mal o desaparecen.",
                    symbol: "textformat",
                    requiresAdmin: true,
                    command: "\(atsutil) databases -remove"
                )
            )
        }

        if let mdutil = firstExisting(["/usr/bin/mdutil"]) {
            list.append(
                OptimizeTask(
                    id: "spotlight",
                    title: "Reindexar Spotlight",
                    detail: "Reconstruye el índice de búsqueda del disco de arranque.",
                    symbol: "magnifyingglass",
                    requiresAdmin: true,
                    command: "\(mdutil) -E /"
                )
            )
        }

        if let newsyslog = firstExisting(["/usr/sbin/newsyslog"]) {
            list.append(
                OptimizeTask(
                    id: "logs",
                    title: "Rotar registros del sistema",
                    detail: "Compacta los logs antiguos del sistema.",
                    symbol: "doc.plaintext",
                    requiresAdmin: true,
                    command: "\(newsyslog) -v"
                )
            )
        }

        if let diskutil = firstExisting(["/usr/sbin/diskutil"]) {
            list.append(
                OptimizeTask(
                    id: "verify",
                    title: "Verificar el disco",
                    detail: "Comprobación de solo lectura del volumen de arranque.",
                    symbol: "internaldrive",
                    requiresAdmin: true,
                    command: "\(diskutil) verifyVolume /"
                )
            )
        }

        return list
    }

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
