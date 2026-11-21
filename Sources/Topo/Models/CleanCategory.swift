import SwiftUI

struct CleanItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let categoryID: String
}

enum CleanMode: Hashable {
    /// Delete the direct children of each root.
    case contents
    /// Delete the root itself.
    case item
}

struct CleanCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let group: String
    let roots: [URL]
    let mode: CleanMode
    let requiresAdmin: Bool
    /// Categories that hold data a user may still want (archives, repos).
    let isSensitive: Bool
}

extension CleanCategory {
    private static func home(_ path: String) -> URL {
        Paths.expand(path)
    }

    static let all: [CleanCategory] = [
        // MARK: Usuario
        CleanCategory(
            id: "user-caches",
            title: "Cachés de aplicaciones",
            detail: "Archivos temporales que las apps regeneran solas",
            symbol: "shippingbox",
            tint: Color(red: 0.36, green: 0.72, blue: 1.00),
            group: "Usuario",
            roots: [home("~/Library/Caches")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "user-logs",
            title: "Registros (logs)",
            detail: "Historial de actividad de aplicaciones",
            symbol: "doc.text.magnifyingglass",
            tint: Color(red: 0.42, green: 0.78, blue: 0.62),
            group: "Usuario",
            roots: [home("~/Library/Logs")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "user-crash",
            title: "Informes de fallos",
            detail: "Diagnósticos generados tras un cierre inesperado",
            symbol: "exclamationmark.triangle",
            tint: Color(red: 0.95, green: 0.66, blue: 0.32),
            group: "Usuario",
            roots: [home("~/Library/Logs/DiagnosticReports")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "user-saved-state",
            title: "Estados guardados",
            detail: "Ventanas y sesiones de apps que ya no importan",
            symbol: "rectangle.stack",
            tint: Color(red: 0.64, green: 0.62, blue: 0.95),
            group: "Usuario",
            roots: [home("~/Library/Saved Application State")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "user-trash",
            title: "Papelera",
            detail: "Archivos que ya marcaste para eliminar",
            symbol: "trash",
            tint: Color(red: 0.90, green: 0.45, blue: 0.45),
            group: "Usuario",
            roots: [home("~/.Trash")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: true
        ),

        // MARK: Desarrollo
        CleanCategory(
            id: "dev-derived",
            title: "Xcode DerivedData",
            detail: "Índices y builds intermedios de tus proyectos",
            symbol: "hammer",
            tint: Color(red: 0.44, green: 0.68, blue: 1.00),
            group: "Desarrollo",
            roots: [home("~/Library/Developer/Xcode/DerivedData")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-devicesupport",
            title: "Xcode DeviceSupport",
            detail: "Símbolos de depuración de versiones antiguas de iOS",
            symbol: "iphone",
            tint: Color(red: 0.56, green: 0.60, blue: 0.98),
            group: "Desarrollo",
            roots: [home("~/Library/Developer/Xcode/iOS DeviceSupport")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-archives",
            title: "Xcode Archives",
            detail: "Comprobantes de distribuciones anteriores (no se recrean)",
            symbol: "archivebox",
            tint: Color(red: 0.98, green: 0.56, blue: 0.40),
            group: "Desarrollo",
            roots: [home("~/Library/Developer/Xcode/Archives")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: true
        ),
        CleanCategory(
            id: "dev-swiftpm",
            title: "Swift Package Manager",
            detail: "Repositorios y cachés de dependencias",
            symbol: "swift",
            tint: Color(red: 0.96, green: 0.44, blue: 0.36),
            group: "Desarrollo",
            roots: [home("~/Library/Caches/org.swift.swiftpm"), home("~/Library/org.swift.swiftpm")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-cocoapods",
            title: "CocoaPods",
            detail: "Caché de pods descargados",
            symbol: "circle.hexagongrid",
            tint: Color(red: 0.90, green: 0.36, blue: 0.36),
            group: "Desarrollo",
            roots: [home("~/Library/Caches/CocoaPods")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-npm",
            title: "npm",
            detail: "Caché global de paquetes de Node",
            symbol: "cube.box",
            tint: Color(red: 0.84, green: 0.38, blue: 0.36),
            group: "Desarrollo",
            roots: [home("~/.npm/_cacache")],
            mode: .item,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-yarn-pnpm",
            title: "Yarn y pnpm",
            detail: "Almacenes de paquetes descargados",
            symbol: "shippingbox.and.arrow.backward",
            tint: Color(red: 0.44, green: 0.64, blue: 0.98),
            group: "Desarrollo",
            roots: [home("~/Library/Caches/Yarn"), home("~/Library/pnpm/store")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-gradle",
            title: "Gradle",
            detail: "Caché de builds y dependencias de Java",
            symbol: "cup.and.saucer",
            tint: Color(red: 0.40, green: 0.76, blue: 0.60),
            group: "Desarrollo",
            roots: [home("~/.gradle/caches"), home("~/.gradle/wrapper/dists")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-maven",
            title: "Maven",
            detail: "Repositorio local de artefactos Java",
            symbol: "tray.full",
            tint: Color(red: 0.86, green: 0.56, blue: 0.34),
            group: "Desarrollo",
            roots: [home("~/.m2/repository")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: true
        ),
        CleanCategory(
            id: "dev-pip",
            title: "pip y go-build",
            detail: "Ruedas de Python y objetos compilados de Go",
            symbol: "chevron.left.forwardslash.chevron.right",
            tint: Color(red: 0.44, green: 0.78, blue: 0.86),
            group: "Desarrollo",
            roots: [home("~/Library/Caches/pip"), home("~/Library/Caches/go-build")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "dev-homebrew",
            title: "Homebrew",
            detail: "Descargas de fórmulas ya instaladas",
            symbol: "mug",
            tint: Color(red: 0.94, green: 0.66, blue: 0.36),
            group: "Desarrollo",
            roots: [home("~/Library/Caches/Homebrew")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),

        // MARK: Navegadores
        CleanCategory(
            id: "web-chrome",
            title: "Google Chrome",
            detail: "Caché de sitios, imágenes y scripts",
            symbol: "globe",
            tint: Color(red: 0.96, green: 0.72, blue: 0.30),
            group: "Navegadores",
            roots: [home("~/Library/Caches/Google/Chrome")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "web-safari",
            title: "Safari",
            detail: "Caché web del navegador del sistema",
            symbol: "safari",
            tint: Color(red: 0.36, green: 0.66, blue: 0.98),
            group: "Navegadores",
            roots: [home("~/Library/Caches/com.apple.Safari")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "web-firefox",
            title: "Firefox",
            detail: "Caché de perfiles de Firefox",
            symbol: "flame",
            tint: Color(red: 0.96, green: 0.52, blue: 0.28),
            group: "Navegadores",
            roots: [home("~/Library/Caches/Firefox")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),
        CleanCategory(
            id: "web-edge",
            title: "Microsoft Edge",
            detail: "Caché de navegación de Edge",
            symbol: "circle.grid.cross",
            tint: Color(red: 0.34, green: 0.72, blue: 0.86),
            group: "Navegadores",
            roots: [home("~/Library/Caches/Microsoft Edge")],
            mode: .contents,
            requiresAdmin: false,
            isSensitive: false
        ),

        // MARK: Sistema
        CleanCategory(
            id: "sys-library-caches",
            title: "Cachés del sistema",
            detail: "Cachés compartidas en /Library/Caches (requiere contraseña)",
            symbol: "gearshape.2",
            tint: Color(red: 0.72, green: 0.72, blue: 0.78),
            group: "Sistema",
            roots: [URL(fileURLWithPath: "/Library/Caches")],
            mode: .contents,
            requiresAdmin: true,
            isSensitive: true
        )
    ]

    static let groups: [String] = {
        var seen: [String] = []
        for category in all where !seen.contains(category.group) {
            seen.append(category.group)
        }
        return seen
    }()
}
