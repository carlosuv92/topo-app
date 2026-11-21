import Foundation

/// Verificaciones rápidas de la política de borrado.
/// Uso: topo --selftest
enum SafetySelfTest {
    private static var failures = 0

    static func run() -> Int32 {
        let home = Paths.home
        let caches = home.appendingPathComponent("Library/Caches")
        let documents = home.appendingPathComponent("Documents")

        check(
            "hijo de una raíz permitida",
            SafetyPolicy.validate(caches.appendingPathComponent("foo"), within: [caches]),
            expected: true
        )
        check(
            "la raíz misma se rechaza por defecto",
            SafetyPolicy.validate(caches, within: [caches]),
            expected: false
        )
        check(
            "la raíz misma se acepta con allowSame",
            SafetyPolicy.validate(caches, within: [caches], allowSame: true),
            expected: true
        )
        check(
            "rutas protegidas del sistema",
            SafetyPolicy.validate(URL(fileURLWithPath: "/System/Library/CoreServices"), within: [URL(fileURLWithPath: "/System")]),
            expected: false
        )
        check(
            "Documentos del usuario",
            SafetyPolicy.validate(documents.appendingPathComponent("informe.pdf"), within: [documents]),
            expected: false
        )
        check(
            "escape con ..",
            SafetyPolicy.validate(caches.appendingPathComponent("../Documents/x"), within: [caches]),
            expected: false
        )
        check(
            "raíz ajena",
            SafetyPolicy.validate(home.appendingPathComponent("Library/Logs/a"), within: [caches]),
            expected: false
        )

        // Symlink: debe rechazarse aunque el destino esté dentro.
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("topo-selftest-\(UUID().uuidString)")
        let link = temp.appendingPathComponent("link")
        try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: caches)
        check(
            "symlink rechazado",
            SafetyPolicy.validate(link, within: [temp]),
            expected: false
        )
        try? FileManager.default.removeItem(at: temp)

        print(failures == 0 ? "✓ Política de seguridad: todo correcto" : "✗ \(failures) fallo(s)")
        return failures == 0 ? 0 : 1
    }

    private static func check(_ name: String, _ result: Bool, expected: Bool) {
        let ok = result == expected
        if !ok { failures += 1 }
        print("\(ok ? "✓" : "✗") \(name) → \(result) (esperado \(expected))")
    }
}
