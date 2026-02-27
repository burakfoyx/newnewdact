import Foundation
import Combine
import Darwin

/// Represents the CPU usage of a single thread
struct ThreadCPUUsage: Identifiable, Equatable {
    let id: mach_port_t // thread port
    var cpuUsage: Double // percentage
}

@MainActor
class AppProfiler: ObservableObject {
    static let shared = AppProfiler()
    
    @Published var totalAppCPUUsage: Double = 0.0
    @Published var threadUsages: [ThreadCPUUsage] = []
    
    private var timer: Timer?
    
    private init() {}
    
    func startProfiling() {
        stopProfiling()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        updateMetrics() // Initial snapshot
    }
    
    func stopProfiling() {
        timer?.invalidate()
        timer = nil
        totalAppCPUUsage = 0.0
        threadUsages.removeAll()
    }
    
    private func updateMetrics() {
        let (total, threads) = calculateCPUUsage()
        
        // Dispatch to Main Actor
        Task { @MainActor in
            self.totalAppCPUUsage = total
            self.threadUsages = threads.sorted(by: { $0.cpuUsage > $1.cpuUsage })
        }
    }
    
    /// Reads Mach thread info to calculate CPU usage per thread and the total app usage.
    private func calculateCPUUsage() -> (Double, [ThreadCPUUsage]) {
        var totalCPU: Double = 0.0
        var threadStats: [ThreadCPUUsage] = []
        
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        // Get all threads for the current task
        let task = mach_task_self_
        let result = task_threads(task, &threadList, &threadCount)
        
        guard result == KERN_SUCCESS, let threads = threadList else {
            return (0.0, [])
        }
        
        for i in 0..<Int(threadCount) {
            let thread = threads[i]
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                    thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            if infoResult == KERN_SUCCESS {
                let isIdle = (threadInfo.flags & TH_FLAGS_IDLE) != 0
                if !isIdle {
                    // CPU usage is expressed as a fraction of TH_USAGE_SCALE
                    let usage = Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                    totalCPU += usage
                    threadStats.append(ThreadCPUUsage(id: thread, cpuUsage: usage))
                }
            }
        }
        
        // Deallocate the thread list memory returned by the kernel
        let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
        vm_deallocate(task, vm_address_t(bitPattern: threads), size)
        
        return (totalCPU, threadStats)
    }
}
