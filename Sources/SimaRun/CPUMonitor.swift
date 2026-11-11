import Darwin

/// CPU load between two consecutive samples. All values are fractions 0...1.
struct CPUSample {
    var user: Double
    var system: Double
    var idle: Double
    var cores: [Double]

    var total: Double { user + system }
}

/// Reads per-core tick counters from the kernel (public Mach API, no entitlements needed)
/// and reports the load since the previous call.
final class CPUMonitor {
    private struct Ticks {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    private let host = mach_host_self()
    private var previous: [Ticks] = []

    /// Returns nil on the very first call (nothing to compare against yet) or if the kernel call fails.
    func sample() -> CPUSample? {
        guard let current = readTicks() else { return nil }
        defer { previous = current }
        guard previous.count == current.count else { return nil }

        var user = 0.0, system = 0.0, idle = 0.0
        var cores: [Double] = []
        cores.reserveCapacity(current.count)

        for (now, before) in zip(current, previous) {
            // Counters are 32-bit and wrap around; wrapping subtraction keeps deltas correct.
            let u = Double(now.user &- before.user) + Double(now.nice &- before.nice)
            let s = Double(now.system &- before.system)
            let i = Double(now.idle &- before.idle)
            let all = u + s + i
            cores.append(all > 0 ? (u + s) / all : 0)
            user += u
            system += s
            idle += i
        }

        let all = user + system + idle
        guard all > 0 else { return nil }
        return CPUSample(user: user / all, system: system / all, idle: idle / all, cores: cores)
    }

    private func readTicks() -> [Ticks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            // The kernel allocates this buffer in our address space; we must release it.
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { cpu in
            let base = cpu * stride
            return Ticks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
        }
    }
}
