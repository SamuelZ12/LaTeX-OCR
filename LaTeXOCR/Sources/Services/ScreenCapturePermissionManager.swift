import Foundation
import CoreGraphics
import AppKit
import Combine

@MainActor
final class ScreenCapturePermissionManager: ObservableObject {
    static let shared = ScreenCapturePermissionManager()

    /// Published property for reactive UI updates
    @Published private(set) var hasPermission: Bool = false

    /// Timer for periodic permission checking
    private var permissionCheckTimer: Timer?

    /// Polling interval in seconds
    private let pollingInterval: TimeInterval = 2.0

    private init() {
        hasPermission = CGPreflightScreenCaptureAccess()
    }

    /// Request permission and start monitoring for changes
    func requestPermissionAndStartMonitoring() {
        // Trigger the system permission dialog
        let result = CGRequestScreenCaptureAccess()
        hasPermission = result

        // If not granted, start polling
        if !hasPermission {
            startPolling()
        }
    }

    /// Check permission status once
    func checkPermission() -> Bool {
        hasPermission = CGPreflightScreenCaptureAccess()
        return hasPermission
    }

    /// Start polling for permission changes
    private func startPolling() {
        stopPolling()

        permissionCheckTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pollPermission()
            }
        }
    }

    /// Stop polling
    func stopPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    /// Single poll iteration
    private func pollPermission() {
        let granted = CGPreflightScreenCaptureAccess()
        if granted && !hasPermission {
            hasPermission = true
            stopPolling()
            Logger.log(.info, "Screen capture permission granted")
        }
    }

    /// Open System Settings to the Screen Recording pane
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
