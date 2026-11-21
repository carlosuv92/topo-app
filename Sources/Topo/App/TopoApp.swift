import SwiftUI

@main
struct TopoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var monitor = SystemMonitor()

    init() {
        let arguments = CommandLine.arguments

        if arguments.contains("--help") || arguments.contains("-h") {
            CleanupCLI.help()
            exit(0)
        }
        if arguments.contains("--version") || arguments.contains("-v") {
            print("topo \(CleanupCLI.version)")
            exit(0)
        }
        if arguments.contains("--scan") {
            CleanupCLI.run()
            exit(0)
        }
        if arguments.contains("--selftest") {
            exit(SafetySelfTest.run())
        }
        if arguments.contains("--permissions") {
            CleanupCLI.permissions()
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(monitor)
                .frame(minWidth: 980, minHeight: 640)
                .task { monitor.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("Bienvenida de Topo") {
                    NotificationCenter.default.post(name: .topoShowWelcome, object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(monitor)
        } label: {
            MenuBarLabel(metrics: monitor.metrics)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuBarLabel: View {
    let metrics: Metrics

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 11, weight: .semibold))
            Text("\(Int(metrics.cpu * 100))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
}

private struct MenuBarPanel: View {
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Estado del Mac")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            row(
                label: "CPU",
                value: "\(Int(monitor.metrics.cpu * 100))%",
                fraction: monitor.metrics.cpu,
                tint: Palette.status
            )
            row(
                label: "Memoria",
                value: "\(monitor.metrics.memoryUsed.bytes) / \(monitor.metrics.memoryTotal.bytes)",
                fraction: monitor.metrics.memoryFraction,
                tint: Palette.optimize
            )
            row(
                label: "Disco",
                value: "\(monitor.metrics.diskFree.bytes) libres",
                fraction: monitor.metrics.diskFraction,
                tint: Palette.analyze
            )

            if let level = monitor.metrics.batteryLevel {
                HStack {
                    Text("Batería").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(level)%\(monitor.metrics.batteryCharging ? " ⚡︎" : "")")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }

            Divider()

            Button("Salir de Topo") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 270)
    }

    private func row(label: String, value: String, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            MetricBar(value: fraction, tint: tint, height: 4)
        }
    }
}
