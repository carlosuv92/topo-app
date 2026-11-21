import Foundation
import Darwin
import IOKit.ps

struct ProcessSample: Identifiable, Hashable {
    var id: Int { pid }
    let pid: Int
    let name: String
    let cpu: Double
    let memory: Double
}

struct Metrics {
    var cpu: Double = 0
    var cpuHistory: [Double] = []

    var memoryUsed: Int64 = 0
    var memoryTotal: Int64 = 0
    var memoryHistory: [Double] = []

    var diskFree: Int64 = 0
    var diskTotal: Int64 = 0

    var netDown: Double = 0
    var netUp: Double = 0
    var netDownHistory: [Double] = []
    var netUpHistory: [Double] = []

    var load1: Double = 0
    var load5: Double = 0
    var load15: Double = 0

    var uptime: TimeInterval = 0
    var batteryLevel: Int?
    var batteryCharging: Bool = false
    var batteryOnAC: Bool = false

    var processes: [ProcessSample] = []

    var chipName: String = ""
    var coreCount: Int = 0
    var physicalMemory: Int64 = 0

    var memoryFraction: Double {
        guard memoryTotal > 0 else { return 0 }
        return min(Double(memoryUsed) / Double(memoryTotal), 1)
    }

    var diskFraction: Double {
        guard diskTotal > 0 else { return 0 }
        return min(Double(diskTotal - diskFree) / Double(diskTotal), 1)
    }
}

/// Samples system metrics once per second on the main run loop.
/// Mach calls are cheap; only `ps` runs off the main thread.
@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var metrics = Metrics()

    private var timer: Timer?
    private var cpuSampler = CPUSampler()
    private var lastNet: (down: Double, up: Double, at: Date)?
    private var tick = 0

    init() {
        metrics.memoryTotal = Int64(ProcessInfo.processInfo.physicalMemory)
        metrics.physicalMemory = metrics.memoryTotal
        metrics.coreCount = ProcessInfo.processInfo.processorCount
        metrics.chipName = Self.chipName()
        refreshDisk()
    }

    func start() {
        guard timer == nil else { return }
        sample()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        tick += 1

        let cpu = cpuSampler.sample()
        metrics.cpu = cpu
        push(&metrics.cpuHistory, cpu)

        sampleMemory()

        if let net = NetworkSampler.sample() {
            if let previous = lastNet {
                let dt = max(Date().timeIntervalSince(previous.at), 0.1)
                metrics.netDown = max((net.down - previous.down) / dt, 0)
                metrics.netUp = max((net.up - previous.up) / dt, 0)
            }
            lastNet = (net.down, net.up, Date())
        }
        push(&metrics.netDownHistory, metrics.netDown)
        push(&metrics.netUpHistory, metrics.netUp)

        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 {
            metrics.load1 = loads[0]
            metrics.load5 = loads[1]
            metrics.load15 = loads[2]
        }

        metrics.uptime = ProcessInfo.processInfo.systemUptime
        sampleBattery()

        if tick % 5 == 0 {
            refreshDisk()
        }
        if tick % 3 == 1 {
            refreshProcesses()
        }
    }

    // MARK: - Memory

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let page = Int64(vm_kernel_page_size)
        let active = Int64(stats.active_count) * page
        let wired = Int64(stats.wire_count) * page
        let compressed = Int64(stats.compressor_page_count) * page

        metrics.memoryUsed = active + wired + compressed
        push(&metrics.memoryHistory, metrics.memoryFraction)
    }

    // MARK: - Disk / battery / processes

    private func refreshDisk() {
        let info = DiskAnalyzer.volumeInfo(for: URL(fileURLWithPath: "/"))
        if info.total > 0 {
            metrics.diskFree = info.free
            metrics.diskTotal = info.total
        }
    }

    private func sampleBattery() {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            metrics.batteryLevel = nil
            return
        }

        for source in list {
            guard
                let description = IOPSGetPowerSourceDescription(snapshot, source)?
                    .takeUnretainedValue() as? [String: Any]
            else { continue }

            if let capacity = description[kIOPSCurrentCapacityKey] as? Int,
               let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 {
                metrics.batteryLevel = Int((Double(capacity) / Double(max)) * 100)
            }
            metrics.batteryCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            metrics.batteryOnAC =
                (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return
        }
    }

    private func refreshProcesses() {
        Task.detached(priority: .utility) {
            let result = Shell.run(
                "/bin/ps",
                ["-A", "-o", "pid=,ucomm=,%cpu=,%mem=", "-r"],
                timeout: 5
            )

            var totals: [String: (pid: Int, cpu: Double, memory: Double)] = [:]

            for line in result.stdout.split(separator: "\n") {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 4,
                      let pid = Int(parts[0]),
                      let cpu = Double(parts[parts.count - 2]),
                      let memory = Double(parts[parts.count - 1])
                else { continue }

                let name = parts[1..<(parts.count - 2)].joined(separator: " ")
                guard !name.isEmpty else { continue }

                if let existing = totals[name] {
                    totals[name] = (existing.pid, existing.cpu + cpu, existing.memory + memory)
                } else {
                    totals[name] = (pid, cpu, memory)
                }
            }

            let samples = totals
                .map { ProcessSample(pid: $0.value.pid, name: $0.key, cpu: $0.value.cpu, memory: $0.value.memory) }
                .sorted { $0.cpu > $1.cpu }
                .prefix(6)
                .map { $0 }

            await MainActor.run { self.metrics.processes = samples }
        }
    }

    // MARK: - Helpers

    private func push(_ array: inout [Double], _ value: Double) {
        array.append(value)
        if array.count > 60 { array.removeFirst(array.count - 60) }
    }

    private static func chipName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        let name = String(cString: buffer).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Apple Silicon" : name
    }
}

/// Per-core CPU deltas between samples.
struct CPUSampler {
    private var previous: [(busy: Double, total: Double)] = []

    mutating func sample() -> Double {
        var information: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &information,
            &infoCount
        )

        guard result == KERN_SUCCESS, let information else { return 0 }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: information),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        var current: [(busy: Double, total: Double)] = []
        current.reserveCapacity(Int(cpuCount))

        for cpu in 0..<Int(cpuCount) {
            let base = Int(CPU_STATE_MAX) * cpu
            let user = Double(information[base + Int(CPU_STATE_USER)])
            let system = Double(information[base + Int(CPU_STATE_SYSTEM)])
            let nice = Double(information[base + Int(CPU_STATE_NICE)])
            let idle = Double(information[base + Int(CPU_STATE_IDLE)])
            current.append((busy: user + system + nice, total: user + system + nice + idle))
        }

        defer { previous = current }

        guard previous.count == current.count, !current.isEmpty else { return 0 }

        var usage = 0.0
        for index in current.indices {
            let deltaBusy = current[index].busy - previous[index].busy
            let deltaTotal = current[index].total - previous[index].total
            if deltaTotal > 0 {
                usage += max(min(deltaBusy / deltaTotal, 1), 0)
            }
        }

        return usage / Double(current.count)
    }
}

enum NetworkSampler {
    /// Cumulative bytes in/out across physical interfaces.
    static func sample() -> (down: Double, up: Double)? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }

        var down = 0.0
        var up = 0.0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let data = current.pointee.ifa_data
            else { continue }

            let name = String(cString: current.pointee.ifa_name)
            if name == "lo0" || name.hasPrefix("gif") || name.hasPrefix("stf") { continue }

            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            down += Double(stats.ifi_ibytes)
            up += Double(stats.ifi_obytes)
        }

        return (down, up)
    }
}
