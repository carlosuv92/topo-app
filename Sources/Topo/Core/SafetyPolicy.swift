import Foundation

/// Every deletion in topo goes through this policy.
///
/// The rule is allowlist-based: an item can only be removed when it lives
/// strictly inside one of the roots declared by its own category. On top of
/// that, a deny list protects the parts of the system where a cleanup tool has
/// no business being.
enum SafetyPolicy {

    /// Paths (and their contents) that must never be touched, regardless of
    /// what a category declares.
    static let protectedPaths: [String] = [
        "/",
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/etc",
        "/private/etc",
        "/private/var/db",
        "/Library/Apple",
        "/Library/Extensions",
        "/Library/LaunchDaemons",
        "/Library/LaunchAgents",
        "/Library/PrivilegedHelperTools",
        "~/Library/Keychains",
        "~/Library/Preferences",
        "~/Library/Mobile Documents",
        "~/Library/Application Support/MobileSync",
        "~/Library/Application Support/AddressBook",
        "~/Library/Mail",
        "~/Library/Messages",
        "~/Documents",
        "~/Desktop",
        "~/Downloads",
        "~/Pictures",
        "~/Movies",
        "~/Music"
    ]

    static func isProtected(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        for raw in protectedPaths {
            let candidate = (raw as NSString).expandingTildeInPath
            if path == candidate || path.hasPrefix(candidate + "/") {
                return true
            }
        }
        return false
    }

    /// True when `url` is a strict descendant of one of `roots`, is not a
    /// symlink/alias, and is not protected.
    ///
    /// `allowSame` admits the case where the item *is* the root itself, which
    /// happens for categories that manage a single directory (npm cache, for
    /// example).
    static func validate(_ url: URL, within roots: [URL], allowSame: Bool = false) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isAliasFileKey])
        if values?.isSymbolicLink == true { return false }
        if values?.isAliasFile == true { return false }

        if isProtected(url) { return false }

        let target = url.standardizedFileURL.path
        for root in roots {
            let base = root.standardizedFileURL.path
            let isSame = allowSame && base == target
            let isChild = target.hasPrefix(base + "/")
            guard isSame || isChild else { continue }

            // A path can look contained but resolve elsewhere through a
            // symlinked parent. Re-check after resolution.
            let resolved = url.resolvingSymlinksInPath().path
            if resolved == target || resolved.hasPrefix(base + "/") {
                return true
            }
        }
        return false
    }
}
