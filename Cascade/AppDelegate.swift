import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var cpuMonitor: CPUMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Cascade starting...")
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Cascade")
            button.action = #selector(menuBarClicked)
            button.target = self
        }
        
        // Initialize CPU monitor
        cpuMonitor = CPUMonitor()
        cpuMonitor?.startMonitoring()
        
        print("✅ Cascade running!")
    }
    
    @objc func menuBarClicked() {
        print("Menu bar clicked!")
        if let cpuUsage = cpuMonitor?.getCurrentUsage() {
            print("CPU Usage: \(String(format: "%.1f", cpuUsage))%")
        }
    }
}

// MARK: - CPU Monitor
class CPUMonitor {
    private var timer: Timer?
    private var previousCPUInfo: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateCPU()
        }
        // Run once immediately
        updateCPU()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCPU() {
        if let usage = getCPUUsage() {
            print("📊 CPU: \(String(format: "%.1f", usage))%")
        }
    }
    
    func getCurrentUsage() -> Double? {
        return getCPUUsage()
    }
    
    private func getCPUUsage() -> Double? {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUsU,
            &cpuInfo,
            &numCPUInfo
        )
        
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return nil
        }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size))
        }
        
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        
        for i in 0..<Int(numCPUsU) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(cpuInfo[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)])
        }
        
        let total = totalUser + totalSystem + totalIdle + totalNice
        
        if let previous = previousCPUInfo {
            let prevTotal = previous.user + previous.system + previous.idle + previous.nice
            let totalDelta = total - prevTotal
            let idleDelta = totalIdle - previous.idle
            
            if totalDelta > 0 {
                let usage = Double(totalDelta - idleDelta) / Double(totalDelta) * 100.0
                previousCPUInfo = (totalUser, totalSystem, totalIdle, totalNice)
                return usage
            }
        }
        
        previousCPUInfo = (totalUser, totalSystem, totalIdle, totalNice)
        return nil
    }
}
