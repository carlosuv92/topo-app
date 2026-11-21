import Foundation
import AppKit

struct AppBundle: Identifiable, Hashable {
    var id: String { bundleURL.path }
    let bundleURL: URL
    let name: String
    let bundleID: String?
    let version: String
    var size: Int64
    let isSystem: Bool
}

struct Leftover: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let size: Int64
    let kind: String
    let requiresAdmin: Bool
}

enum AppScanner {

    static let searchDirectories: [URL] = [
        Paths.expand("~/Applications"),
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        URL(fileURLWithPath: "/System/Applications/Utilities")
    ]

    static func appBundles() -> [AppBundle] {
        let fm = FileManager.default
        var seen = Set<String>()
        var result: [AppBundle] = []

        for directory in searchDirectories {
            guard let entries = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.pathExtension == "app" {
                guard seen.insert(entry.path).inserted else { continue }

                let bundle = Bundle(url: entry)
                let identifier = bundle?.bundleIdentifier
                let version =
                    bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                    ?? "—"
                let displayName =
                    bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? entry.deletingPathExtension().lastPathComponent

                let isSystem = entry.path.hasPrefix("/System/") || entry.path.hasPrefix("/Applications/Utilities")

                result.append(
                    AppBundle(
                        bundleURL: entry,
                        name: displayName,
                        bundleID: identifier,
                        version: version,
                        size: 0,
                        isSystem: isSystem
                    )
                )
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Known locations where a macOS app leaves data outside its bundle.
    static func leftovers(for app: AppBundle) -> [Leftover] {
        let fm = FileManager.default
        var candidates: [(URL, String, Bool)] = []

        let home = Paths.home

        if let bundleID = app.bundleID, !bundleID.isEmpty {
            let userTemplates: [(String, String)] = [
                ("~/Library/Application Support/\(bundleID)", "Datos de la app"),
                ("~/Library/Caches/\(bundleID)", "Caché"),
                ("~/Library/Preferences/\(bundleID).plist", "Preferencias"),
                ("~/Library/Logs/\(bundleID)", "Registros"),
                ("~/Library/Saved Application State/\(bundleID).savedState", "Estado guardado"),
                ("~/Library/Containers/\(bundleID)", "Contenedor"),
                ("~/Library/HTTPStorages/\(bundleID)", "Almacenamiento HTTP"),
                ("~/Library/HTTPStorages/\(bundleID).binarycookies", "Cookies"),
                ("~/Library/WebKit/\(bundleID)", "Datos web"),
                ("~/Library/LaunchAgents/\(bundleID).plist", "Agente de arranque"),
                ("~/Library/Application Scripts/\(bundleID)", "Scripts")
            ]
            for (path, kind) in userTemplates {
                candidates.append((Paths.expand(path), kind, false))
            }

            let systemTemplates: [(String, String)] = [
                ("/Library/Application Support/\(bundleID)", "Datos compartidos"),
                ("/Library/Caches/\(bundleID)", "Caché del sistema"),
                ("/Library/Preferences/\(bundleID).plist", "Preferencias del sistema"),
                ("/Library/LaunchAgents/\(bundleID).plist", "Agente de arranque"),
                ("/Library/LaunchDaemons/\(bundleID).plist", "Demonio de arranque")
            ]
            for (path, kind) in systemTemplates {
                candidates.append((URL(fileURLWithPath: path), kind, true))
            }
        }

        // Fallback by display name, only for very likely locations.
        candidates.append((home.appendingPathComponent("Library/Application Support/\(app.name)"), "Datos de la app", false))
        candidates.append((home.appendingPathComponent("Library/Caches/\(app.name)"), "Caché", false))
        candidates.append((home.appendingPathComponent("Library/Logs/\(app.name)"), "Registros", false))

        var result: [Leftover] = []
        var visited = Set<String>()

        for (url, kind, requiresAdmin) in candidates {
            guard visited.insert(url.path).inserted else { continue }
            guard fm.fileExists(atPath: url.path) else { continue }
            guard url.standardizedFileURL.path != app.bundleURL.standardizedFileURL.path else { continue }
            result.append(
                Leftover(
                    url: url,
                    size: CleanupEngine.size(of: url),
                    kind: kind,
                    requiresAdmin: requiresAdmin
                )
            )
        }

        // Group Containers are prefixed with a team identifier, so match by suffix.
        if let bundleID = app.bundleID, !bundleID.isEmpty {
            let groupRoot = home.appendingPathComponent("Library/Group Containers")
            if let groups = try? fm.contentsOfDirectory(at: groupRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for group in groups where group.lastPathComponent.contains(bundleID) {
                    guard visited.insert(group.path).inserted else { continue }
                    result.append(
                        Leftover(
                            url: group,
                            size: CleanupEngine.size(of: group),
                            kind: "Group Container",
                            requiresAdmin: false
                        )
                    )
                }
            }
        }

        return result.sorted { $0.size > $1.size }
    }

    static func isRunning(_ app: AppBundle) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func terminate(_ app: AppBundle) {
        guard let bundleID = app.bundleID else { return }
        for instance in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            instance.terminate()
        }
    }
}
