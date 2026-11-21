import SwiftUI

enum Palette {
    static let clean = Color(red: 0.18, green: 0.78, blue: 0.56)
    static let software = Color(red: 0.32, green: 0.58, blue: 1.00)
    static let optimize = Color(red: 0.63, green: 0.48, blue: 0.98)
    static let analyze = Color(red: 1.00, green: 0.63, blue: 0.26)
    static let status = Color(red: 1.00, green: 0.40, blue: 0.44)

    static let surface = Color(nsColor: .controlBackgroundColor)
    static let hairline = Color.primary.opacity(0.08)
}

enum Section: String, CaseIterable, Identifiable {
    case clean, software, optimize, analyze, status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: return "Limpieza"
        case .software: return "Aplicaciones"
        case .optimize: return "Optimizar"
        case .analyze: return "Disco"
        case .status: return "Estado"
        }
    }

    var symbol: String {
        switch self {
        case .clean: return "sparkles"
        case .software: return "square.grid.2x2"
        case .optimize: return "slider.horizontal.3"
        case .analyze: return "chart.pie"
        case .status: return "waveform.path.ecg"
        }
    }

    var tint: Color {
        switch self {
        case .clean: return Palette.clean
        case .software: return Palette.software
        case .optimize: return Palette.optimize
        case .analyze: return Palette.analyze
        case .status: return Palette.status
        }
    }

    var subtitle: String {
        switch self {
        case .clean: return "Cachés, registros y restos que ya no necesitas"
        case .software: return "Desinstala apps junto con todo lo que dejan"
        case .optimize: return "Mantenimiento del sistema con un clic"
        case .analyze: return "Encuentra qué está ocupando tu disco"
        case .status: return "CPU, memoria, red y batería en vivo"
        }
    }
}

// MARK: - Estado sin macros
//
// macOS 27 define `@State` como macro y el plugin `SwiftUIMacros` solo viene
// con Xcode completo. Con Command Line Tools usamos `@StateObject`, que sigue
// siendo un property wrapper normal.

final class HoverBox: ObservableObject {
    @Published var isOn = false
}

// MARK: - Contenedores

struct Card<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
    }
}

struct IconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(tint)
            )
    }
}

struct Pill: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.4)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
            .foregroundStyle(tint)
    }
}

// MARK: - Acciones

struct ActionButton: View {
    let title: String
    let symbol: String
    var tint: Color = .accentColor
    var filled: Bool = true
    var disabled: Bool = false
    var action: () -> Void

    @StateObject private var hover = HoverBox()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .foregroundStyle(filled ? Color.white : tint)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(filled ? tint.opacity(hover.isOn ? 1.0 : 0.9) : tint.opacity(hover.isOn ? 0.16 : 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(filled ? Color.clear : tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .onHover { hover.isOn = $0 }
    }
}

// MARK: - Datos

struct MetricBar: View {
    let value: Double
    var tint: Color = Palette.clean
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * min(max(value, 0), 1), value > 0 ? 3 : 0))
            }
        }
        .frame(height: height)
    }
}

struct Sparkline: View {
    let values: [Double]
    var tint: Color
    var filled: Bool = true

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let peak = max(values.max() ?? 0, 0.0001)
            let stepX = size.width / CGFloat(max(values.count - 1, 1))

            var line = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height - (CGFloat(value / peak) * size.height * 0.92) - 1
                if index == 0 {
                    line.move(to: CGPoint(x: x, y: y))
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                }
            }

            if filled {
                var area = line
                area.addLine(to: CGPoint(x: size.width, y: size.height))
                area.addLine(to: CGPoint(x: 0, y: size.height))
                area.closeSubpath()
                context.fill(
                    area,
                    with: .linearGradient(
                        Gradient(colors: [tint.opacity(0.28), tint.opacity(0.0)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }

            context.stroke(line, with: .color(tint), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        }
    }
}

struct StatBlock: View {
    let label: String
    let value: String
    var tint: Color = .primary
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            if let caption {
                Text(caption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct CheckCircle: View {
    let isOn: Bool
    var tint: Color

    var body: some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isOn ? tint : Color.secondary.opacity(0.45))
    }
}

/// Icono real de la app (el .icns del bundle), recortado a squircle.
/// Si se ejecuta sin bundle (swift run) cae en un marcador con el degradado.
struct AppIconMark: View {
    var size: CGFloat = 28

    private var bundleIcon: NSImage? {
        guard
            let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
            let image = NSImage(contentsOfFile: path)
        else { return nil }
        return image
    }

    var body: some View {
        Group {
            if let bundleIcon {
                Image(nsImage: bundleIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.clean, Palette.software],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: size * 0.44, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }
}

/// Segmento dentro de un control agrupado (estilo "Todo | Nada").
struct SplitAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    @StateObject private var hover = HoverBox()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(hover.isOn ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hover.isOn ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isOn = $0 }
    }
}
