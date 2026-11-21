import Foundation

struct UninstallReport {
    var trashed: Int = 0
    var freed: Int64 = 0
    var failures: [String] = []

    var summary: String {
        if failures.isEmpty {
            return "\(trashed) elemento\(trashed == 1 ? "" : "s") movido\(trashed == 1 ? "" : "s") a la Papelera · \(freed.bytes)"
        }
        return "Movidos \(trashed) · \(freed.bytes). \(failures.count) con problemas."
    }
}

enum Uninstaller {

    static func uninstall(app: AppBundle, leftovers: [Leftover], moveToTrash: Bool = true) -> UninstallReport {
        var report = UninstallReport()

        if AppScanner.isRunning(app) {
            AppScanner.terminate(app)
            // Give the app a moment to flush its state before removing files.
            Thread.sleep(forTimeInterval: 1.2)
        }

        var adminLeftovers: [Leftover] = []

        var targets: [URL] = [app.bundleURL]
        targets.append(contentsOf: leftovers.filter { !$0.requiresAdmin }.map(\.url))
        adminLeftovers = leftovers.filter(\.requiresAdmin)

        for url in targets {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                if moveToTrash {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try FileManager.default.removeItem(at: url)
                }
                report.trashed += 1
                report.freed += CleanupEngine.size(of: url)
            } catch {
                report.failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !adminLeftovers.isEmpty {
            let command = adminLeftovers
                .map { "rm -rf \(Paths.quote($0.url.path))" }
                .joined(separator: " ; ")
            let result = Admin.run(command)
            if result.ok {
                report.trashed += adminLeftovers.count
                report.freed += adminLeftovers.reduce(0) { $0 + $1.size }
            } else {
                report.failures.append(
                    "Elementos del sistema no eliminados: \(result.combined)"
                )
            }
        }

        return report
    }
}
