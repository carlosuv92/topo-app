import Foundation

struct DiskEntry: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
}

enum DiskAnalyzer {

    /// Sizes of the direct children of `directory`, largest first.
    static func children(of directory: URL) -> [DiskEntry] {
        childURLs(of: directory)
            .map(entry(for:))
            .sorted { $0.size > $1.size }
    }

    static func childURLs(of directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )) ?? []
    }

    static func entry(for url: URL) -> DiskEntry {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return DiskEntry(
            url: url,
            name: url.lastPathComponent,
            size: CleanupEngine.size(of: url),
            isDirectory: isDirectory
        )
    }

    /// Largest individual files under `root`, ignoring noisy system paths.
    static func largeFiles(
        under root: URL,
        minSize: Int64 = 200_000_000,
        limit: Int = 60
    ) -> [DiskEntry] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

        let skipped: [String] = [
            "/System",
            "/private/var/vm",
            "/Volumes",
            "/dev"
        ]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var found: [DiskEntry] = []
        var counter = 0

        for case let url as URL in enumerator {
            counter += 1
            if counter % 512 == 0 && Task.isCancelled { break }
            if skipped.contains(where: { url.path.hasPrefix($0) }) {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= minSize else { continue }

            found.append(DiskEntry(url: url, name: url.lastPathComponent, size: size, isDirectory: false))
            if found.count > limit * 4 {
                found.sort { $0.size > $1.size }
                found = Array(found.prefix(limit))
            }
        }

        return Array(found.sorted { $0.size > $1.size }.prefix(limit))
    }

    static func volumeInfo(for url: URL) -> (free: Int64, total: Int64) {
        let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])
        let free = values?.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        return (max(free, 0), total)
    }
}
