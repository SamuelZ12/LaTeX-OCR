import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController {
    static var shared: SettingsWindowController?
    
    convenience init() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentViewController = hostingController
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 450, height: 400)
        
        self.init(window: window)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func showWindow(_ sender: Any?) {
        // Create a fresh window if needed to avoid ViewBridge issues
        if window == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }
        
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    static func showSettings() {
        if shared == nil {
            shared = SettingsWindowController()
        }
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
