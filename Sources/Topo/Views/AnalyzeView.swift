import AppKit
import SwiftUI

@MainActor
final class AnalyzeModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case browse, large
        var id: String { rawValue }
        var label: String { self == .browse ? "Explorar" : "Archivos grandes" }
    }

    @Published var path = Paths.home
    @Published var entries: [DiskEntry] = []
    @Published var loading = false
    @Published var mode: Mode = .browse

    private var loadTask: Task<Void, Never>?

    @Published var largeFiles: [DiskEntry] = []
    @Published var largeScanning = false
    @Published var largeScanned = false

    /// Trailing components of `path` relative to the home directory.
    var breadcrumbs: [(title: String, url: URL)] {
        let home = Paths.home.standardizedFileURL.path
        let current = path.standardizedFileURL.path

        if current == "/" {
            return [("Macintosh HD", URL(fileURLWithPath: "/"))]
        }

        guard current.hasPrefix(home + "/") || current == home else {
            return [("Macintosh HD", URL(fileURLWithPath: "/")), (path.lastPathComponent, path)]
        }

        var result: [(String, URL)] = [("Inicio", Paths.home)]
        guard current != home else { return result }

        let relative = String(current.dropFirst(home.count)).split(separator: "/")
        var accumulated = Paths.home
        for component in relative {
            accumulated.appendPathComponent(String(component))
            result.append((String(component), accumulated))
        }
        return result
    }

    var totalSize: Int64 { entries.reduce(0) { $0 + $1.size } }

    func load(_ url: URL) {
        loadTask?.cancel()
        path = url
        loading = true
        entries = []
        let target = url

        loadTask = Task { [weak self] in
            let children = await Task.detached(priority: .userInitiated) {
                DiskAnalyzer.childURLs(of: target)
            }.value

            var results: [DiskEntry] = []
            for child in children {
                if Task.isCancelled { return }
                let entry = await Task.detached(priority: .userInitiated) {
                    DiskAnalyzer.entry(for: child)
                }.value
                if Task.isCancelled { return }
                results.append(entry)
                results.sort { $0.size > $1.size }
                self?.entries = results
            }

            self?.loading = false
        }
    }

    func enter(_ entry: DiskEntry) {
        guard entry.isDirectory else {
            NSWorkspace.shared.activateFileViewerSelecting([entry.url])
            return
        }
        load(entry.url)
    }

    func findLarge() {
        guard !largeScanning else { return }
        mode = .large
        largeScanning = true
        largeScanned = true
        largeFiles = []
        Task {
            let found = await Task.detached(priority: .utility) {
                DiskAnalyzer.largeFiles(under: Paths.home)
            }.value
            largeFiles = found
            largeScanning = false
        }
    }
}

struct AnalyzeView: View {
    @StateObject private var model = AnalyzeModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            browserBar
            Divider().opacity(0.5)

            if model.mode == .browse {
                browseContent
            } else {
                largeContent
            }
        }
        .onAppear {
            if model.entries.isEmpty && !model.loading {
                model.load(Paths.home)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: Section.analyze.symbol)
                        .foregroundStyle(Palette.analyze)
                    Text(Section.analyze.title)
                        .font(.system(size: 19, weight: .semibold))
                }
                Text(Section.analyze.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(AnalyzeModel.Mode.allCases) { mode in
                    Button {
                        if mode == .large {
                            model.findLarge()
                        } else {
                            model.mode = .browse
                        }
                    } label: {
                        Text(mode.label)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(model.mode == mode ? Palette.analyze.opacity(0.18) : Color.clear)
                            )
                            .foregroundStyle(model.mode == mode ? Palette.analyze : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 14)
    }

    private var browserBar: some View {
        HStack(spacing: 8) {
            Button {
                let parent = model.path.deletingLastPathComponent()
                if parent.path != model.path.path { model.load(parent) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                    .padding(5)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .disabled(model.path.path == "/")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(model.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            model.load(crumb.url)
                        } label: {
                            Text(crumb.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(index == model.breadcrumbs.count - 1 ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            if model.mode == .browse {
                Text(model.entries.isEmpty ? "—" : model.totalSize.bytes)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.analyze)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var browseContent: some View {
        if model.loading && model.entries.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Calculando tamaños…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.entries.isEmpty {
            EmptyState(
                symbol: "folder",
                title: "Carpeta vacía",
                detail: "No hay nada que analizar en esta ubicación."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.entries) { entry in
                        entryRow(entry)
                    }
                    if model.loading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Calculando el resto…")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
        }
    }

    private func entryRow(_ entry: DiskEntry) -> some View {
        let fraction = model.totalSize > 0 ? Double(entry.size) / Double(model.totalSize) : 0
        return Button {
            model.enter(entry)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(entry.isDirectory ? Palette.analyze : Color.secondary.opacity(0.6))
                    .frame(width: 18)

                Text(entry.name)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 190, alignment: .leading)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Palette.analyze.opacity(0.85), Palette.analyze.opacity(0.45)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 3 : 0))
                    }
                }
                .frame(height: 7)

                Text(entry.size.bytes)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 78, alignment: .trailing)

                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)
                } else {
                    Color.clear.frame(width: 10)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var largeContent: some View {
        if model.largeScanning {
            VStack(spacing: 10) {
                ProgressView()
                Text("Buscando archivos de más de 200 MB…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.largeFiles.isEmpty {
            EmptyState(
                symbol: "checkmark.seal",
                title: "Sin archivos gigantes",
                detail: "No encontramos archivos de más de 200 MB en tu carpeta personal."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.largeFiles) { file in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.analyze.opacity(0.7))
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.name)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .lineLimit(1)
                                Text(file.url.deletingLastPathComponent().path
                                    .replacingOccurrences(of: Paths.home.path, with: "~"))
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Text(file.size.bytes)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.analyze)
                                .monospacedDigit()

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([file.url])
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
        }
    }
}
