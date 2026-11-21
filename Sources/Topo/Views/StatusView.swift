import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280), spacing: 12)],
                    spacing: 12
                ) {
                    cpuCard
                    memoryCard
                    diskCard
                    networkCard
                    batteryCard
                    machineCard
                    processesCard
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: Section.status.symbol)
                        .foregroundStyle(Palette.status)
                    Text(Section.status.title)
                        .font(.system(size: 19, weight: .semibold))
                }
                Text(Section.status.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.clean)
                    .frame(width: 6, height: 6)
                Text("En vivo")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
        }
        .padding(.horizontal, 22)
        .padding(.top, 34)
        .padding(.bottom, 14)
    }

    // MARK: - Tarjetas

    private var cpuCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("CPU", symbol: "cpu", tint: Palette.status)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(monitor.metrics.cpu * 100))")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(monitor.metrics.coreCount) núcleos")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                Sparkline(values: monitor.metrics.cpuHistory, tint: Palette.status)
                    .frame(height: 44)
                HStack(spacing: 14) {
                    load(label: "1m", value: monitor.metrics.load1)
                    load(label: "5m", value: monitor.metrics.load5)
                    load(label: "15m", value: monitor.metrics.load15)
                }
            }
        }
    }

    private var memoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("Memoria", symbol: "memorychip", tint: Palette.optimize)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(monitor.metrics.memoryUsed.bytes)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("de \(monitor.metrics.memoryTotal.bytes)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                MetricBar(value: monitor.metrics.memoryFraction, tint: Palette.optimize, height: 7)
                HStack {
                    Text("\(Int(monitor.metrics.memoryFraction * 100))% en uso")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(monitor.metrics.diskFree.bytes) libres en disco")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Sparkline(values: monitor.metrics.memoryHistory, tint: Palette.optimize)
                    .frame(height: 32)
            }
        }
    }

    private var diskCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("Disco", symbol: "internaldrive", tint: Palette.analyze)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(monitor.metrics.diskFree.bytes)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("libres")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                MetricBar(value: monitor.metrics.diskFraction, tint: Palette.analyze, height: 7)
                HStack {
                    Text("\(Int(monitor.metrics.diskFraction * 100))% ocupado")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Total \(monitor.metrics.diskTotal.bytes)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var networkCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("Red", symbol: "network", tint: Palette.software)
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Palette.software)
                            Text(speed(monitor.metrics.netDown))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        Text("descarga")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Palette.optimize)
                            Text(speed(monitor.metrics.netUp))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        Text("subida")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                    }
                }
                Sparkline(values: monitor.metrics.netDownHistory, tint: Palette.software)
                    .frame(height: 34)
            }
        }
    }

    private var batteryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("Batería", symbol: "battery.75", tint: Palette.clean)
                if let level = monitor.metrics.batteryLevel {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(level)")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Pill(
                            text: monitor.metrics.batteryCharging
                                ? "cargando"
                                : (monitor.metrics.batteryOnAC ? "corriente" : "batería"),
                            tint: monitor.metrics.batteryCharging ? Palette.clean : .secondary
                        )
                    }
                    MetricBar(
                        value: Double(level) / 100,
                        tint: level < 20 ? Palette.status : Palette.clean,
                        height: 7
                    )
                } else {
                    Text("Este Mac no reporta batería.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
                Text("Encendido hace \(uptime)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var machineCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("Equipo", symbol: "desktopcomputer", tint: Palette.optimize)
                VStack(alignment: .leading, spacing: 6) {
                    infoRow("Chip", monitor.metrics.chipName)
                    infoRow("Núcleos", "\(monitor.metrics.coreCount)")
                    infoRow("Memoria", monitor.metrics.memoryTotal.bytes)
                    infoRow("Sistema", ProcessInfo.processInfo.operatingSystemVersionString)
                }
            }
        }
    }

    private var processesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 9) {
                cardTitle("Procesos con más CPU", symbol: "list.bullet.rectangle", tint: Palette.analyze)
                if monitor.metrics.processes.isEmpty {
                    Text("Midiendo…")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(monitor.metrics.processes.prefix(5)) { process in
                        HStack(spacing: 8) {
                            Text(process.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(String(format: "%.1f%%", process.cpu))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 46, alignment: .trailing)
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.06))
                                    Capsule()
                                        .fill(Palette.analyze.opacity(0.75))
                                        .frame(width: max(proxy.size.width * min(process.cpu / 100, 1), 2))
                                }
                            }
                            .frame(width: 60, height: 4)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Piezas

    private func cardTitle(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func load(label: String, value: Double) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(String(format: "%.2f", value))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    private func speed(_ bytesPerSecond: Double) -> String {
        let value = Int64(max(bytesPerSecond, 0))
        return "\(value.bytes)/s"
    }

    private var uptime: String {
        let total = Int(monitor.metrics.uptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
