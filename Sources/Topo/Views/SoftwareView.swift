import AppKit
import SwiftUI

@MainActor
final class SoftwareModel: ObservableObject {
    @Published var apps: [AppBundle] = []
    @Published var isLoading = false
    @Published var query = ""
    @Published var selection: AppBundle.ID?
    @Published var leftovers: [Leftover] = []
    @Published var loadingLeftovers = false
    @Published var banner: String?
    @Published var isUninstalling = false
    @Published var confirming = false

    private var scanTask: Task<Void, Never>?

    var filtered: [AppBundle] {
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || ($0.bundleID?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var selectedApp: AppBundle? {
        guard let selection else { return nil }
        return apps.first { $0.id == selection }
    }

    var userApps: [AppBundle] { filtered.filter { !$0.isSystem } }
    var systemApps: [AppBundle] { filtered.filter(\.isSystem) }

    func scan() {
        guard !isLoading else { return }
        isLoading = true
        banner = nil
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            let bundles = await Task.detached(priority: .utility) {
                AppScanner.appBundles()
            }.value
            if Task.isCancelled { return }
            self.apps = bundles
            self.isLoading = false

            for index in bundles.indices {
                if Task.isCancelled { return }
                let url = bundles[index].bundleURL
                let size = await Task.detached(priority: .utility) {
                    CleanupEngine.size(of: url)
                }.value
                if Task.isCancelled { return }
                if let current = self.apps.firstIndex(where: { $0.id == bundles[index].id }) {
                    self.apps[current].size = size
                }
            }
        }
    }

    func loadLeftovers(for app: AppBundle) {
        loadingLeftovers = true
        leftovers = []
        let bundle = app
        Task {
            let found = await Task.detached(priority: .utility) {
                AppScanner.leftovers(for: bundle)
            }.value
            leftovers = found
            loadingLeftovers = false
        }
    }

    func uninstall() {
        guard let app = selectedApp else { return }
        isUninstalling = true
        let found = leftovers
        Task {
            let report = await Task.detached(priority: .userInitiated) {
                Uninstaller.uninstall(app: app, leftovers: found)
            }.value
            isUninstalling = false
            banner = report.summary
            apps.removeAll { $0.id == app.id }
            selection = nil
            leftovers = []
        }
    }
}

struct SoftwareView: View {
    @StateObject private var model = SoftwareModel()
    @StateObject private var permissions = PermissionsModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            HStack(spacing: 0) {
                appList
                Rectangle().fill(Palette.hairline).frame(width: 1)
                detail
            }
        }
        .onAppear {
            if model.apps.isEmpty { model.scan() }
        }
        .confirmationDialog(
            "¿Desinstalar \(model.selectedApp?.name ?? "")?",
            isPresented: $model.confirming,
            titleVisibility: .visible
        ) {
            Button("Desinstalar y limpiar restos", role: .destructive) {
                model.uninstall()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("La app y sus archivos asociados se moverán a la Papelera. Podrás recuperarlos hasta vaciarla.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: Section.software.symbol)
                        .foregroundStyle(Palette.software)
                    Text(Section.software.title)
                        .font(.system(size: 19, weight: .semibold))
                }
                Text(Section.software.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                SearchField(text: $model.query)
                    .frame(width: 200)
                ActionButton(
                    title: model.isLoading ? "Leyendo…" : "Reescanear",
                    symbol: "arrow.clockwise",
                    tint: Palette.software,
                    filled: false,
                    disabled: model.isLoading
                ) {
                    model.scan()
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 14)
    }

    private var appList: some View {
        Group {
            if model.isLoading && model.apps.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Leyendo aplicaciones…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        if !model.userApps.isEmpty {
                            groupLabel("Instaladas por ti")
                            ForEach(model.userApps) { app in
                                appRow(app)
                            }
                        }
                        if !model.systemApps.isEmpty {
                            groupLabel("Del sistema")
                            ForEach(model.systemApps) { app in
                                appRow(app)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(minWidth: 320, idealWidth: 380)
        .frame(maxWidth: .infinity)
    }

    private func groupLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func appRow(_ app: AppBundle) -> some View {
        let isSelected = model.selection == app.id
        return Button {
            model.selection = app.id
            model.loadLeftovers(for: app)
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable()
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(app.bundleID ?? "sin identificador")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(app.size > 0 ? app.size.bytes : "—")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Palette.software.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if !permissions.hasFullDiskAccess {
                PermissionBanner(model: permissions, compact: true)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }

            detailContent
        }
        .frame(minWidth: 380)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var detailContent: some View {
        Group {
            if let app = model.selectedApp {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                                .resizable()
                                .frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Versión \(app.version)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                if app.isSystem {
                                    Pill(text: "app del sistema", tint: Palette.analyze)
                                }
                            }
                            Spacer()
                        }

                        Card {
                            HStack(spacing: 22) {
                                StatBlock(label: "Tamaño app", value: app.size.bytes)
                                StatBlock(
                                    label: "Restos",
                                    value: model.loadingLeftovers ? "…" : model.leftovers.reduce(0) { $0 + $1.size }.bytes,
                                    tint: Palette.software,
                                    caption: "\(model.leftovers.count) ubicaciones"
                                )
                            }
                        }

                        HStack(spacing: 8) {
                            Button("Mostrar en Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.software)

                            Spacer()

                            ActionButton(
                                title: model.isUninstalling ? "Desinstalando…" : "Desinstalar",
                                symbol: "trash",
                                tint: Palette.status,
                                disabled: app.isSystem || model.isUninstalling
                            ) {
                                model.confirming = true
                            }
                        }

                        if let banner = model.banner {
                            Text(banner)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Palette.software.opacity(0.10))
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Archivos asociados")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if model.loadingLeftovers {
                                    ProgressView().controlSize(.mini)
                                }
                            }

                            if !model.loadingLeftovers && model.leftovers.isEmpty {
                                Text("No se encontraron restos. La app parece limpia.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .padding(.vertical, 6)
                            }

                            Card(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(Array(model.leftovers.enumerated()), id: \.element.id) { offset, item in
                                        if offset > 0 { Divider().opacity(0.4) }
                                        HStack(spacing: 8) {
                                            Image(systemName: item.requiresAdmin ? "lock.shield" : "doc")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                                .frame(width: 14)
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text(item.kind)
                                                    .font(.system(size: 11, weight: .medium))
                                                Text(item.url.path.replacingOccurrences(of: Paths.home.path, with: "~"))
                                                    .font(.system(size: 9.5))
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                            Spacer()
                                            Text(item.size.bytes)
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 5)
                                    }
                                }
                            }
                        }
                    }
                    .padding(22)
                }
            } else {
                EmptyState(
                    symbol: "square.grid.2x2",
                    title: "Selecciona una aplicación",
                    detail: "Elige una app de la lista para ver qué archivos deja fuera de su paquete."
                )
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            TextField("Buscar", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
