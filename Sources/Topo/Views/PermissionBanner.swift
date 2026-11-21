import AppKit
import SwiftUI

/// Aviso para pedir Acceso Total al Disco, al estilo de las apps nativas:
/// aparece solo cuando hace falta y lleva directo al panel correcto.
struct PermissionBanner: View {
    @ObservedObject var model: PermissionsModel
    var compact: Bool = false

    var body: some View {
        if !model.hasFullDiskAccess {
            HStack(alignment: .top, spacing: 11) {
                IconBadge(symbol: "lock.shield", tint: Palette.analyze, size: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Activa el Acceso Total al Disco")
                        .font(.system(size: 12, weight: .semibold))

                    Text(
                        compact
                            ? "Así topo puede leer restos de apps dentro de ~/Library/Containers."
                            : "macOS protege Correo, Safari, Mensajes y parte de ~/Library/Containers. Sin este permiso esas zonas se omiten y algunos restos de apps no se detectan."
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    if model.justRechecked {
                        Text("Sigue sin estar activo. Si acabas de concederlo, cierra y vuelve a abrir topo.")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.analyze)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    ActionButton(
                        title: "Abrir Ajustes",
                        symbol: "arrow.up.forward.app",
                        tint: Palette.analyze,
                        filled: false
                    ) {
                        Permissions.openFullDiskAccessSettings()
                    }

                    Button("Ya lo activé") {
                        model.refresh()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.analyze.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.analyze.opacity(0.18), lineWidth: 1)
            )
        }
    }
}
