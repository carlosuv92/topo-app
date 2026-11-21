import AppKit
import SwiftUI

@MainActor
final class CleanModel: ObservableObject {
    struct Row: Identifiable {
        var id: String { category.id }
        let category: CleanCategory
        var items: [CleanItem] = []
        var selected: Set<UUID> = []
        var scanned = false
        var error: String?

        var size: Int64 { items.reduce(0) { $0 + $1.size } }
        var selectedSize: Int64 {
            items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.size }
        }
    }

    @Published var rows: [Row] = CleanCategory.all.map { Row(category: $0) }
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var banner: String?
    @Published var expanded: Set<Int> = []
    @Published var showingReview = false

    private var task: Task<Void, Never>?

    var totalSize: Int64 { rows.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { rows.reduce(0) { $0 + $1.selectedSize } }
    var selectedCount: Int { rows.reduce(0) { $0 + $1.selected.count } }
    var hasScanned: Bool { rows.contains { $0.scanned } }

    var reviewGroups: [ReviewGroup] {
        rows.compactMap { row in
            let items = row.items.filter { row.selected.contains($0.id) }
            guard !items.isEmpty else { return nil }
            return ReviewGroup(category: row.category, items: items)
        }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        banner = nil
        for index in rows.indices {
            rows[index].items = []
            rows[index].selected = []
            rows[index].scanned = false
            rows[index].error = nil
        }

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            let indices = Array(self.rows.indices)
            for index in indices {
                if Task.isCancelled { break }
                let category = self.rows[index].category
                let items = await Task.detached(priority: .utility) {
                    CleanupEngine.scan(category)
                }.value
                if Task.isCancelled { break }

                self.rows[index].items = items
                self.rows[index].selected = category.isSensitive
                    ? []
                    : Set(items.map(\.id))
                self.rows[index].scanned = true
            }
            self.isScanning = false
        }
    }

    func toggle(_ rowIndex: Int, _ item: CleanItem) {
        if rows[rowIndex].selected.contains(item.id) {
            rows[rowIndex].selected.remove(item.id)
        } else {
            rows[rowIndex].selected.insert(item.id)
        }
    }

    func toggleGroup(_ rowIndex: Int) {
        let row = rows[rowIndex]
        rows[rowIndex].selected = row.selected.count == row.items.count
            ? []
            : Set(row.items.map(\.id))
    }

    func selectAll() {
        for index in rows.indices {
            rows[index].selected = Set(rows[index].items.map(\.id))
        }
    }

    func selectNone() {
        for index in rows.indices {
            rows[index].selected = []
        }
    }

    func clean() {
        let selection = rows.flatMap { row in
            row.items.filter { row.selected.contains($0.id) }
        }
        guard !selection.isEmpty else { return }

        isCleaning = true
        let categories = Dictionary(uniqueKeysWithValues: CleanCategory.all.map { ($0.id, $0) })

        Task {
            let report = await Task.detached(priority: .userInitiated) {
                CleanupEngine.delete(items: selection, categories: categories)
            }.value

            isCleaning = false
            banner = report.summary
            if !report.failures.isEmpty {
                banner = report.summary + " " + report.failures.prefix(3).joined(separator: " · ")
            }
            scan()
        }
    }
}

struct CleanView: View {
    @StateObject private var model = CleanModel()
    @StateObject private var permissions = PermissionsModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            bodyContent
        }
        .onAppear {
            if !model.hasScanned { model.scan() }
        }
        .sheet(isPresented: $model.showingReview) {
            ReviewSheet(
                groups: model.reviewGroups,
                total: model.selectedSize
            ) {
                model.clean()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: Section.clean.symbol)
                        .foregroundStyle(Palette.clean)
                    Text(Section.clean.title)
                        .font(.system(size: 19, weight: .semibold))
                }
                Text(Section.clean.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                ActionButton(
                    title: model.isScanning ? "Escaneando…" : "Escanear",
                    symbol: "arrow.clockwise",
                    tint: Palette.clean,
                    filled: false,
                    disabled: model.isScanning || model.isCleaning
                ) {
                    model.scan()
                }

                ActionButton(
                    title: model.isCleaning
                        ? "Limpiando…"
                        : "Revisar y limpiar",
                    symbol: "checklist",
                    tint: Palette.clean,
                    disabled: model.selectedCount == 0 || model.isScanning || model.isCleaning
                ) {
                    model.showingReview = true
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if !model.hasScanned && model.isScanning {
            VStack(spacing: 12) {
                ProgressView()
                Text("Analizando tu Mac…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    PermissionBanner(model: permissions)

                    summary

                    if let banner = model.banner {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Palette.clean)
                            Text(banner)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Palette.clean.opacity(0.10))
                        )
                    }

                    ForEach(CleanCategory.groups, id: \.self) { group in
                        let indices = model.rows.indices.filter { model.rows[$0].category.group == group }
                        if indices.contains(where: { !model.rows[$0].items.isEmpty }) || isGroupScanning(indices) {
                            groupSection(group: group, indices: indices)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
        }
    }

    private var summary: some View {
        Card {
            HStack(spacing: 26) {
                StatBlock(
                    label: "Encontrado",
                    value: model.totalSize.bytes,
                    tint: .primary,
                    caption: model.isScanning ? "escaneando…" : "\(model.rows.reduce(0) { $0 + $1.items.count }) elementos"
                )
                StatBlock(
                    label: "Seleccionado",
                    value: model.selectedSize.bytes,
                    tint: Palette.clean,
                    caption: "\(model.selectedCount) marcados"
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 7) {
                    HStack(spacing: 2) {
                        SplitAction(title: "Todo", symbol: "checkmark.circle.fill") {
                            model.selectAll()
                        }
                        SplitAction(title: "Nada", symbol: "circle.slash") {
                            model.selectNone()
                        }
                    }
                    .padding(2)
                    .background(
                        Capsule().fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        Capsule().strokeBorder(Palette.hairline, lineWidth: 1)
                    )

                    Text("Los elementos sensibles llegan desmarcados.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func isGroupScanning(_ indices: [Int]) -> Bool {
        model.isScanning && indices.contains { !model.rows[$0].scanned }
    }

    private func groupSection(group: String, indices: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(group)
                    .font(.system(size: 10.5, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                let size = indices.reduce(Int64(0)) { $0 + model.rows[$1].size }
                if size > 0 {
                    Text(size.bytes)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 2)

            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(indices.enumerated()), id: \.element) { offset, index in
                        if offset > 0 {
                            Divider().opacity(0.4).padding(.leading, 48)
                        }
                        rowView(index: index)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(index: Int) -> some View {
        let row = model.rows[index]
        let isOn = row.items.isEmpty
            ? false
            : row.selected.count == row.items.count

        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button {
                    model.toggleGroup(index)
                } label: {
                    CheckCircle(isOn: isOn, tint: row.category.tint)
                }
                .buttonStyle(.plain)
                .disabled(row.items.isEmpty)

                IconBadge(symbol: row.category.symbol, tint: row.category.tint, size: 26)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(row.category.title)
                            .font(.system(size: 12.5, weight: .medium))
                        if row.category.requiresAdmin {
                            Pill(text: "admin", tint: .secondary)
                        }
                        if row.category.isSensitive {
                            Pill(text: "revisar", tint: Palette.analyze)
                        }
                    }
                    Text(row.category.detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if !row.scanned {
                    ProgressView().controlSize(.mini)
                } else if row.size > 0 {
                    Text(row.size.bytes)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .monospacedDigit()
                } else {
                    Text("Limpio")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                if !row.items.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if model.expanded.contains(index) {
                                model.expanded.remove(index)
                            } else {
                                model.expanded.insert(index)
                            }
                        }
                    } label: {
                        Image(systemName: model.expanded.contains(index) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { model.toggleGroup(index) }

            if model.expanded.contains(index) {
                VStack(spacing: 0) {
                    ForEach(row.items.prefix(40)) { item in
                        itemRow(item: item, rowIndex: index, tint: row.category.tint)
                    }
                    if row.items.count > 40 {
                        Text("+ \(row.items.count - 40) elementos más")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 5)
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }

    private func itemRow(item: CleanItem, rowIndex: Int, tint: Color) -> some View {
        let isOn = model.rows[rowIndex].selected.contains(item.id)
        return HStack(spacing: 9) {
            Button {
                model.toggle(rowIndex, item)
            } label: {
                CheckCircle(isOn: isOn, tint: tint)
                    .scaleEffect(0.85)
            }
            .buttonStyle(.plain)

            Text(item.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(item.size.bytes)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 40)
        .padding(.trailing, 12)
        .padding(.vertical, 3)
    }
}
