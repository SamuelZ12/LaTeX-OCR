import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static var shared: SettingsWindowController?
    
    convenience init() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentViewController = hostingController
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 450, height: 500)
        
        self.init(window: window)
        window.delegate = self
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
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 450, height: 500)
            self.window = window
        }
        
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }
    
    static func showSettings() {
        if shared == nil {
            shared = SettingsWindowController()
        }
        shared?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
