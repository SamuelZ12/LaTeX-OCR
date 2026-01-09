import AppKit
import SwiftUI

class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    static var shared: OnboardingWindowController?

    convenience init() {
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentViewController = hostingController
        window.title = "Welcome to ScreenScribe"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 480)
        window.maxSize = NSSize(width: 520, height: 480)

        self.init(window: window)
        window.delegate = self
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func showWindow(_ sender: Any?) {
        if window == nil {
            let onboardingView = OnboardingView()
            let hostingController = NSHostingController(rootView: onboardingView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to ScreenScribe"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 520, height: 480)
            window.maxSize = NSSize(width: 520, height: 480)
            self.window = window
        }

        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }

    static func showOnboarding() {
        if shared == nil {
            shared = OnboardingWindowController()
        }
        shared?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
