import Foundation

struct DeleteReport {
    var deleted: Int = 0
    var freed: Int64 = 0
    var failures: [String] = []

    var summary: String {
        if failures.isEmpty {
            return "\(deleted) elemento\(deleted == 1 ? "" : "s") eliminado\(deleted == 1 ? "" : "s") · \(freed.bytes)"
        }
        return "Eliminados \(deleted) · \(freed.bytes). \(failures.count) con problemas."
    }
}

enum CleanupEngine {

    // MARK: - Escaneo

    static func scan(_ category: CleanCategory) -> [CleanItem] {
        let fm = FileManager.default
        var items: [CleanItem] = []

        for root in category.roots {
            if Task.isCancelled { break }

            switch category.mode {
            case .item:
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else { continue }
                let size = size(of: root)
                guard size > 0 else { continue }
                items.append(
                    CleanItem(
                        url: root,
                        name: root.lastPathComponent,
                        size: size,
                        categoryID: category.id
                    )
                )

            case .contents:
                guard let children = try? fm.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
                ) else { continue }

                for child in children {
                    if Task.isCancelled { break }
                    let size = size(of: child)
                    guard size > 0 else { continue }
                    items.append(
                        CleanItem(
                            url: child,
                            name: child.lastPathComponent,
                            size: size,
                            categoryID: category.id
                        )
                    )
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    /// Allocated size of a file or an entire directory tree.
    static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .isRegularFileKey
        ]

        if !isDirectory.boolValue {
            let values = try? url.resourceValues(forKeys: keys)
            return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var counter = 0

        for case let child as URL in enumerator {
            counter += 1
            if counter % 512 == 0 && Task.isCancelled { break }
            guard
                let values = try? child.resourceValues(forKeys: keys),
                values.isRegularFile == true
            else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        return total
    }

    // MARK: - Borrado

    static func delete(items: [CleanItem], categories: [String: CleanCategory]) -> DeleteReport {
        var report = DeleteReport()
        var adminItems: [CleanItem] = []

        for item in items {
            guard let category = categories[item.categoryID] else {
                report.failures.append("Categoría desconocida para \(item.name)")
                continue
            }
            guard SafetyPolicy.validate(
                item.url,
                within: category.roots,
                allowSame: category.mode == .item
            ) else {
                report.failures.append("Bloqueado por seguridad: \(item.url.path)")
                continue
            }

            if category.requiresAdmin {
                adminItems.append(item)
                continue
            }

            do {
                try FileManager.default.removeItem(at: item.url)
                report.deleted += 1
                report.freed += item.size
            } catch {
                report.failures.append("\(item.name): \(error.localizedDescription)")
            }
        }

        if !adminItems.isEmpty {
            let paths = adminItems.map { Paths.quote($0.url.path) }.joined(separator: " ")
            let result = Admin.run("rm -rf \(paths)")
            if result.ok {
                report.deleted += adminItems.count
                report.freed += adminItems.reduce(0) { $0 + $1.size }
            } else {
                report.failures.append(
                    "No se pudieron borrar \(adminItems.count) elementos del sistema: \(result.combined)"
                )
            }
        }

        return report
    }
}

extension Int64 {
    var bytes: String { formatted(.byteCount(style: .file)) }
}
