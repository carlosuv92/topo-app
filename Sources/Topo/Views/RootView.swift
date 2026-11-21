import SwiftUI

@MainActor
final class NavigationModel: ObservableObject {
    @Published var selection: Section = .clean

    init() {
        // Permite abrir la app en una pestaña concreta:
        // open dist/topo.app --env TOPO_TAB=status
        if let raw = ProcessInfo.processInfo.environment["TOPO_TAB"],
           let section = Section(rawValue: raw) {
            selection = section
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @StateObject private var navigation = NavigationModel()
    @StateObject private var onboarding = OnboardingModel()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: $navigation.selection)
                .frame(width: 208)

            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 1)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $onboarding.isPresented) {
            WelcomeSheet(model: onboarding)
        }
        .onReceive(NotificationCenter.default.publisher(for: .topoShowWelcome)) { _ in
            onboarding.isPresented = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.selection {
        case .clean: CleanView()
        case .software: SoftwareView()
        case .optimize: OptimizeView()
        case .analyze: AnalyzeView()
        case .status: StatusView()
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Binding var selection: Section

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 14)
                .padding(.top, 34)
                .padding(.bottom, 18)

            VStack(spacing: 3) {
                ForEach(Section.allCases) { section in
                    SidebarRow(
                        section: section,
                        isSelected: selection == section,
                        action: { selection = section }
                    )
                }
            }
            .padding(.horizontal, 9)

            Spacer(minLength: 12)

            diskFooter
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
    }

    private var brand: some View {
        HStack(spacing: 9) {
            AppIconMark(size: 28)
            VStack(alignment: .leading, spacing: -1) {
                Text("Topo")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("Mantenimiento")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var diskFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Disco")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(monitor.metrics.diskFree.bytes) libres")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            MetricBar(value: monitor.metrics.diskFraction, tint: Palette.analyze, height: 5)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct SidebarRow: View {
    let section: Section
    let isSelected: Bool
    let action: () -> Void

    @StateObject private var hover = HoverBox()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? section.tint : Color.secondary)
                Text(section.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.78))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? section.tint.opacity(0.16)
                            : (hover.isOn ? Color.primary.opacity(0.06) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hover.isOn = $0 }
    }
}
