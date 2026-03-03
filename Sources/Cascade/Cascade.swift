import Foundation
import Cocoa
import SwiftUI

// Main entry point
@main
struct CascadeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Hide dock icon
        app.run()
    }
}

// App Delegate with menu bar and CPU monitoring
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
        
        // Initialize and start CPU monitoring
        cpuMonitor = CPUMonitor()
        cpuMonitor?.startMonitoring()
        
        print("✅ Cascade running in menu bar!")
        print("Click the menu bar icon to see CPU usage")
    }
    
    @objc func menuBarClicked() {
        print("\n📊 === System Status ===")
        if let cpuUsage = cpuMonitor?.getCurrentUsage() {
            print("CPU: \(String(format: "%.1f", cpuUsage))%")
        }
        print("Memory: \(getMemoryUsage())")
        print("========================\n")
    }
    
    private func getMemoryUsage() -> String {
        let total = ProcessInfo.processInfo.physicalMemory
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let used = info.resident_size
            let usedGB = Double(used) / 1073741824
            let totalGB = Double(total) / 1073741824
            return String(format: "%.1f/%.0f GB", usedGB, totalGB)
        }
        return "Unknown"
    }
}

// MARK: - CPU Monitor
class CPUMonitor {
    private var timer: Timer?
    private var previousCPUInfo: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    
    func startMonitoring() {
        // Create run loop for timer
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateCPU()
        }
        RunLoop.current.add(timer!, forMode: .common)
        
        // First update
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
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
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
