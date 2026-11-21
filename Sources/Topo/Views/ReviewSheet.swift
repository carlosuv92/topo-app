import AppKit
import SwiftUI

/// Revisión previa al borrado: muestra exactamente qué se va a eliminar,
/// agrupado por categoría, con rutas y tamaños.
struct ReviewSheet: View {
    let groups: [ReviewGroup]
    let total: Int64
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(groups) { group in
                        section(group)
                    }
                }
                .padding(20)
            }

            Divider().opacity(0.5)
            footer
        }
        .frame(width: 640, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(symbol: "checklist", tint: Palette.clean, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Revisar antes de limpiar")
                    .font(.system(size: 15, weight: .semibold))
                Text("Esto es lo que se va a borrar. Nada se elimina hasta que confirmes.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(total.bytes)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.clean)
                Text("\(itemCount) elementos")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 34)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.analyze)
                Text("Se borra definitivamente: no pasa por la Papelera.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancelar") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ActionButton(
                title: "Eliminar \(total.bytes)",
                symbol: "trash",
                tint: Palette.clean
            ) {
                dismiss()
                onConfirm()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func section(_ group: ReviewGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: group.category.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(group.category.tint)
                Text(group.category.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(group.total.bytes)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { offset, item in
                        if offset > 0 { Divider().opacity(0.35) }
                        HStack(spacing: 9) {
                            Image(systemName: "doc")
                                .font(.system(size: 9))
                                .foregroundStyle(.quaternary)
                                .frame(width: 12)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Text(item.url.path.replacingOccurrences(of: Paths.home.path, with: "~"))
                                    .font(.system(size: 9))
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

    private var itemCount: Int {
        groups.reduce(0) { $0 + $1.items.count }
    }
}

struct ReviewGroup: Identifiable {
    var id: String { category.id }
    let category: CleanCategory
    let items: [CleanItem]

    var total: Int64 { items.reduce(0) { $0 + $1.size } }
}
