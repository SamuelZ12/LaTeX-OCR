import AppKit

NSWindow.swizzleSetFrameDisplayAnimateOnce

_ = NSApplication.shared  // Create singleton instance
let delegate = App()
NSApp.delegate = delegate
NSApp.run()  // Start the run loop
