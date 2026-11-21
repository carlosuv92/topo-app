import SwiftUI

@MainActor
final class OptimizeModel: ObservableObject {
    struct State {
        var running = false
        var result: OptimizeRun?
    }

    @Published var states: [String: State] = [:]
    @Published var runningAll = false

    func isRunning(_ task: OptimizeTask) -> Bool {
        states[task.id]?.running ?? false
    }

    func run(_ task: OptimizeTask) {
        guard !task.requiresAdmin || true else { return }
        states[task.id] = State(running: true, result: nil)
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Optimizer.run(task)
            }.value
            states[task.id] = State(running: false, result: result)
        }
    }

    func runMaintenance() {
        guard !runningAll else { return }
        runningAll = true
        Task {
            for task in Optimizer.tasks where !task.requiresAdmin {
                states[task.id] = State(running: true, result: nil)
                let result = await Task.detached(priority: .userInitiated) {
                    Optimizer.run(task)
                }.value
                states[task.id] = State(running: false, result: result)
            }
            runningAll = false
        }
    }
}

struct OptimizeView: View {
    @StateObject private var model = OptimizeModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            ScrollView {
                VStack(spacing: 12) {
                    Card {
                        HStack(spacing: 12) {
                            IconBadge(symbol: "bolt.shield", tint: Palette.optimize, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mantenimiento seguro")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Ejecuta las tareas que no necesitan contraseña de una sola vez.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            ActionButton(
                                title: model.runningAll ? "Ejecutando…" : "Ejecutar todo",
                                symbol: "play.fill",
                                tint: Palette.optimize,
                                disabled: model.runningAll
                            ) {
                                model.runMaintenance()
                            }
                        }
                    }

                    ForEach(Optimizer.tasks) { task in
                        taskCard(task)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Image(systemName: Section.optimize.symbol)
                    .foregroundStyle(Palette.optimize)
                Text(Section.optimize.title)
                    .font(.system(size: 19, weight: .semibold))
            }
            Text(Section.optimize.subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 14)
    }

    private func taskCard(_ task: OptimizeTask) -> some View {
        let state = model.states[task.id]
        return Card(padding: 13) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 11) {
                    IconBadge(symbol: task.symbol, tint: Palette.optimize, size: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(task.title)
                                .font(.system(size: 12.5, weight: .medium))
                            Pill(
                                text: task.requiresAdmin ? "admin" : "libre",
                                tint: task.requiresAdmin ? Palette.analyze : Palette.clean
                            )
                        }
                        Text(task.detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if state?.running == true {
                        ProgressView().controlSize(.small)
                    } else if let result = state?.result {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(result.success ? Palette.clean : Palette.status)
                    }

                    ActionButton(
                        title: "Ejecutar",
                        symbol: "play.fill",
                        tint: Palette.optimize,
                        filled: false,
                        disabled: state?.running == true
                    ) {
                        model.run(task)
                    }
                }

                if let result = state?.result, !result.output.isEmpty {
                    Text(result.output)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .textSelection(.enabled)
                }
            }
        }
    }
}
