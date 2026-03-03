import Foundation
import Cocoa
import SwiftUI
import Metal

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
    var gpuMonitor: GPUMonitor?
    
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
            let gpuName = self?.gpuMonitor?.getGPUName() ?? "Unknown"
            DispatchQueue.main.async {
                self?.overlayView?.updateMetrics(cpu: cpu, memory: memory, gpu: gpuName)
            }
        }
        gpuMonitor = GPUMonitor()
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
// MARK: - GPU Monitor
class GPUMonitor {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    
    init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
    }
    
    func getGPUName() -> String {
        return device?.name ?? "Unknown"
    }
    
    // Note: Metal doesnt provide direct GPU utilization API
    // This is a simplified version - real implementation would need IOKit
    func getGPUUsage() -> Double {
        // Placeholder: Metal API doesnt expose utilization directly
        // Would need IOKit IOAccelerator for real GPU usage
        return 0.0
    }
}

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
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 200),
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
    var gpuName: String = "Unknown"
    
// Improved draw method for OverlayView
override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    
    // Background with rounded corners
    let background = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
    NSColor.black.withAlphaComponent(0.9).setFill()
    background.fill()
    
    // Matrix green color
    let greenColor = NSColor(red: 0, green: 1.0, blue: 0.25, alpha: 1.0)
    let shadowGreen = NSShadow()
    shadowGreen.shadowColor = greenColor.withAlphaComponent(0.6)
    shadowGreen.shadowOffset = NSSize(width: 0, height: 0)
    shadowGreen.shadowBlurRadius = 6
    
    // Title with glow
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold),
        .foregroundColor: greenColor,
        .shadow: shadowGreen
    ]
    let titleStr = NSAttributedString(string: "CASCADE", attributes: titleAttrs)
    titleStr.draw(at: NSPoint(x: (bounds.width - titleStr.size().width) / 2, y: bounds.height - 35))
    
    let labelAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
        .foregroundColor: greenColor
    ]
    
    let valueAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: greenColor.withAlphaComponent(0.8)
    ]
    
    // Metrics starting position
    var yPos = bounds.height - 65
    
    // CPU Section
    "CPU".draw(at: NSPoint(x: 15, y: yPos), withAttributes: labelAttrs)
    
    // CPU bar with rounded corners
    let cpuBarBg = NSBezierPath(roundedRect: NSRect(x: 60, y: yPos + 2, width: 170, height: 10), xRadius: 5, yRadius: 5)
    NSColor.white.withAlphaComponent(0.15).setFill()
    cpuBarBg.fill()
    
    let cpuProgress = CGFloat(cpuUsage / 100.0) * 170
    if cpuProgress > 0 {
        let cpuBarFill = NSBezierPath(roundedRect: NSRect(x: 60, y: yPos + 2, width: cpuProgress, height: 10), xRadius: 5, yRadius: 5)
        greenColor.setFill()
        cpuBarFill.fill()
    }
    
    String(format: "%.0f%%", cpuUsage).draw(at: NSPoint(x: 240, y: yPos), withAttributes: valueAttrs)
    
    yPos -= 25
    
    // RAM Section
    "RAM".draw(at: NSPoint(x: 15, y: yPos), withAttributes: labelAttrs)
    memoryUsage.draw(at: NSPoint(x: 60, y: yPos), withAttributes: valueAttrs)
    
    yPos -= 25
    
    // GPU Section
    "GPU".draw(at: NSPoint(x: 15, y: yPos), withAttributes: labelAttrs)
    let gpuShort = gpuName.replacingOccurrences(of: "Apple ", with: "")
    gpuShort.draw(at: NSPoint(x: 60, y: yPos), withAttributes: valueAttrs)
    
    // Glowing border
    greenColor.withAlphaComponent(0.5).setStroke()
    let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
    border.lineWidth = 2
    border.stroke()
    
    // Inner subtle glow
    greenColor.withAlphaComponent(0.2).setStroke()
    let innerBorder = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 6, yRadius: 6)
    innerBorder.lineWidth = 1
    innerBorder.stroke()
}
    
    func updateMetrics(cpu: Double, memory: String, gpu: String) {
        self.gpuName = gpu
        self.cpuUsage = cpu
        self.memoryUsage = memory
        self.needsDisplay = true
    }
}
