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
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

// App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var cpuMonitor: CPUMonitor?
    var overlayWindow: OverlayWindow?
    var overlayView: OverlayView?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Cascade starting...")
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "Cascade")
            button.action = #selector(menuBarClicked)
            button.target = self
        }
        
        // Create overlay window
        overlayWindow = OverlayWindow()
        overlayView = OverlayView(frame: overlayWindow!.contentView!.bounds)
        overlayWindow?.contentView = overlayView
        overlayWindow?.orderFrontRegardless()
        
        // Start CPU monitoring
        cpuMonitor = CPUMonitor()
        cpuMonitor?.onUpdate = { [weak self] cpu, memory in
            DispatchQueue.main.async {
                self?.overlayView?.updateMetrics(cpu: cpu, memory: memory)
            }
        }
        cpuMonitor?.startMonitoring()
        
        print("✅ Cascade running with overlay!")
    }
    
    @objc func menuBarClicked() {
        print("Menu clicked - overlay visible: \(overlayWindow?.isVisible ?? false)")
    }
    
    private func getMemoryUsage() -> String {
        let total = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(total) / 1073741824
        return String(format: "%.0f GB", totalGB)
    }
}

// MARK: - CPU Monitor
class CPUMonitor {
    private var timer: Timer?
    private var previousCPUInfo: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    var onUpdate: ((Double, String) -> Void)?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateCPU()
        }
        RunLoop.current.add(timer!, forMode: .common)
        updateCPU()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCPU() {
        if let usage = getCPUUsage() {
            let memory = getMemoryUsage()
            print("📊 CPU: \(String(format: "%.1f", usage))% | RAM: \(memory)")
            onUpdate?(usage, memory)
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
    
    private func getMemoryUsage() -> String {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = vm_statistics64()
        
        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            let total = ProcessInfo.processInfo.physicalMemory
            let active = UInt64(hostInfo.active_count) * UInt64(pageSize)
            let wired = UInt64(hostInfo.wire_count) * UInt64(pageSize)
            let compressed = UInt64(hostInfo.compressor_page_count) * UInt64(pageSize)
            
            let used = active + wired + compressed
            let usedGB = Double(used) / 1073741824
            let totalGB = Double(total) / 1073741824
            return String(format: "%.1f/%.0f GB", usedGB, totalGB)
        }
        return "Unknown"
    }
}

// MARK: - Overlay Window
class OverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        
        // Position in top-right corner
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - 320
            let y = screenRect.maxY - 200
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Overlay View
class OverlayView: NSView {
    var cpuUsage: Double = 0.0
    var memoryUsage: String = "0 GB"
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        NSColor.black.withAlphaComponent(0.85).setFill()
        NSBezierPath(rect: bounds).fill()
        
        // Matrix green color
        let greenColor = NSColor(red: 0, green: 1.0, blue: 0.25, alpha: 1.0)
        
        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .bold),
            .foregroundColor: greenColor
        ]
        "CASCADE".draw(at: NSPoint(x: 20, y: bounds.height - 30), withAttributes: titleAttrs)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: greenColor
        ]
        
        // CPU
        "CPU".draw(at: NSPoint(x: 20, y: bounds.height - 60), withAttributes: labelAttrs)
        
        // CPU bar background
        NSColor.white.withAlphaComponent(0.2).setFill()
        NSBezierPath(rect: NSRect(x: 70, y: bounds.height - 63, width: 150, height: 10)).fill()
        
        // CPU bar fill
        greenColor.setFill()
        let cpuProgress = CGFloat(cpuUsage / 100.0) * 150
        NSBezierPath(rect: NSRect(x: 70, y: bounds.height - 63, width: cpuProgress, height: 10)).fill()
        
        // CPU percentage
        String(format: "%.0f%%", cpuUsage).draw(at: NSPoint(x: 230, y: bounds.height - 60), withAttributes: labelAttrs)
        
        // RAM
        "RAM".draw(at: NSPoint(x: 20, y: bounds.height - 90), withAttributes: labelAttrs)
        memoryUsage.draw(at: NSPoint(x: 70, y: bounds.height - 90), withAttributes: labelAttrs)
        
        // Border glow
        greenColor.withAlphaComponent(0.6).setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()
    }
    
    func updateMetrics(cpu: Double, memory: String) {
        self.cpuUsage = cpu
        self.memoryUsage = memory
        self.needsDisplay = true
    }
}
