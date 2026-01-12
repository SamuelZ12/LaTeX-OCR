import Foundation
import CoreGraphics
import AppKit
import Combine
import ScreenCaptureKit

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
        // Initial check with standard API
        hasPermission = CGPreflightScreenCaptureAccess()

        // If standard API says no permission, verify with ScreenCaptureKit
        // (CGPreflightScreenCaptureAccess can return false even when permission is granted)
        if !hasPermission {
            Task {
                await verifyPermissionViaScreenCaptureKit()
            }
        }
    }

    /// Verify permission using ScreenCaptureKit (more reliable than CGPreflightScreenCaptureAccess)
    private func verifyPermissionViaScreenCaptureKit() async {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            hasPermission = true
            stopPolling()
        } catch {
            // Permission not granted
        }
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
        // Try standard API first
        if CGPreflightScreenCaptureAccess() {
            hasPermission = true
            return true
        }

        // Fallback: verify via ScreenCaptureKit asynchronously
        Task {
            await verifyPermissionViaScreenCaptureKit()
        }

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
                await self?.pollPermission()
            }
        }
    }

    /// Stop polling
    func stopPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    /// Single poll iteration
    private func pollPermission() async {
        // Try standard API first
        if CGPreflightScreenCaptureAccess() {
            if !hasPermission {
                hasPermission = true
                stopPolling()
                Logger.log(.info, "Screen capture permission granted")
            }
            return
        }

        // Fallback: check via ScreenCaptureKit
        await verifyPermissionViaScreenCaptureKit()
        if hasPermission {
            Logger.log(.info, "Screen capture permission granted (via ScreenCaptureKit)")
        }
    }

    /// Open System Settings to the Screen Recording pane
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
