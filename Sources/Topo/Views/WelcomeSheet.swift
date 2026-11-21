import SwiftUI

extension Notification.Name {
    static let topoShowWelcome = Notification.Name("topo.showWelcome")
}

/// Estado del onboarding. Se muestra una sola vez, en el primer arranque.
@MainActor
final class OnboardingModel: ObservableObject {
    private static let key = "topo.onboarding.completed"

    @Published var isPresented: Bool

    init() {
        isPresented = !UserDefaults.standard.bool(forKey: Self.key)
    }

    func finish() {
        UserDefaults.standard.set(true, forKey: Self.key)
        isPresented = false
    }

    /// Útil para volver a ver la bienvenida durante el desarrollo.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Bienvenida de primer arranque, con la petición de permisos al estilo macOS:
/// explicamos qué se necesita, por qué, y llevamos al panel correcto.
struct WelcomeSheet: View {
    @ObservedObject var model: OnboardingModel
    @StateObject private var permissions = PermissionsModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    brand
                    features
                    permissionSection
                }
                .padding(24)
            }

            Divider().opacity(0.5)
            footer
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Secciones

    private var brand: some View {
        HStack(alignment: .center, spacing: 14) {
            AppIconMark(size: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text("Bienvenido a Topo")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Text("Limpieza y mantenimiento para tu Mac, sin atajos peligrosos.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var features: some View {
        VStack(spacing: 0) {
            feature(
                symbol: "sparkles",
                tint: Palette.clean,
                title: "Limpia con revisión previa",
                detail: "Antes de borrar ves la lista exacta de archivos, su ruta y cuánto ocupan."
            )
            Divider().opacity(0.35).padding(.leading, 42)
            feature(
                symbol: "square.grid.2x2",
                tint: Palette.software,
                title: "Desinstala sin dejar restos",
                detail: "La app y sus archivos asociados van a la Papelera, no se borran de golpe."
            )
            Divider().opacity(0.35).padding(.leading, 42)
            feature(
                symbol: "waveform.path.ecg",
                tint: Palette.status,
                title: "Mide tu Mac en vivo",
                detail: "CPU, memoria, disco, red y batería, también desde la barra de menús."
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }

    private func feature(
        symbol: String,
        tint: Color,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            IconBadge(symbol: symbol, tint: tint, size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var permissionSection: some View {
        if permissions.hasFullDiskAccess {
            HStack(spacing: 9) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Palette.clean)
                Text("Acceso Total al Disco activo: Topo puede analizar todas las zonas.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.clean.opacity(0.10))
            )
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.analyze)
                    Text("Acceso Total al Disco (recomendado)")
                        .font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    Pill(text: "opcional", tint: .secondary)
                }

                Text(
                    "macOS protege Correo, Safari, Mensajes y parte de ~/Library/Containers. "
                    + "Sin este permiso Topo funciona igual, pero omite esas zonas al buscar restos."
                )
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Text("Ajustes del Sistema → Privacidad y seguridad → Acceso Total al Disco.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 8) {
                    ActionButton(
                        title: "Abrir Ajustes",
                        symbol: "arrow.up.forward.app",
                        tint: Palette.analyze,
                        filled: false
                    ) {
                        Permissions.openFullDiskAccessSettings()
                    }

                    Button("Ya lo activé") {
                        permissions.refresh()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)

                    Spacer()
                }

                if permissions.justRechecked && !permissions.hasFullDiskAccess {
                    Text("Aún no aparece como activo. Cierra y vuelve a abrir Topo tras concederlo.")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.analyze)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.analyze.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.analyze.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Puedes cambiar los permisos cuando quieras.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer()
            ActionButton(
                title: "Empezar",
                symbol: "arrow.right",
                tint: Palette.clean
            ) {
                model.finish()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}
