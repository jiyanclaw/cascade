import Foundation

// Test basic Swift compilation and system info access
print("🎉 Cascade Development Starting!")
print("User: \(NSUserName())")
print("Mac Model: \(ProcessInfo.processInfo.hostName)")
print("CPU Count: \(ProcessInfo.processInfo.activeProcessorCount)")
print("Memory: \(ProcessInfo.processInfo.physicalMemory / 1073741824)GB")
print("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("\n✅ Swift compilation test successful!")
