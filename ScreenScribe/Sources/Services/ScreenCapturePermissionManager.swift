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
        // (CGPreflightScreenCaptureAccess can return false even when permission is granted on macOS Sequoia)
        if !hasPermission {
            Task {
                _ = await verifyPermissionViaScreenCaptureKit(maxAttempts: 3, delaySeconds: 0.5)
            }
        }
    }

    /// Verify permission using ScreenCaptureKit with retry logic
    /// Returns true if permission is confirmed, false if all attempts fail
    /// On macOS Sequoia, ScreenCaptureKit can throw errors at app launch even when permission is granted
    private func verifyPermissionViaScreenCaptureKit(maxAttempts: Int = 3, delaySeconds: Double = 0.5) async -> Bool {
        for attempt in 1...maxAttempts {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                hasPermission = true
                stopPolling()
                Logger.log(.info, "ScreenCaptureKit permission verified on attempt \(attempt)")
                return true
            } catch {
                Logger.log(.info, "ScreenCaptureKit attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }
        return false
    }

    /// Request permission and start monitoring for changes
    func requestPermissionAndStartMonitoring() async {
        // First, check via ScreenCaptureKit with retries (more reliable on macOS Sequoia)
        // CGPreflightScreenCaptureAccess can return false even when permission is granted
        // ScreenCaptureKit can also throw errors at app launch, so we retry a few times
        let hasPermissionNow = await verifyPermissionViaScreenCaptureKit(maxAttempts: 3, delaySeconds: 0.5)

        // If already granted, no need to show dialog
        if hasPermissionNow {
            Logger.log(.info, "Permission already granted (verified via ScreenCaptureKit with retries)")
            return
        }

        // Only trigger the system permission dialog if truly not granted after retries
        Logger.log(.info, "Permission not detected after retries, showing system dialog")
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

        // Fallback: verify via ScreenCaptureKit asynchronously (with retries)
        Task {
            _ = await verifyPermissionViaScreenCaptureKit(maxAttempts: 3, delaySeconds: 0.5)
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

        // Fallback: check via ScreenCaptureKit (single attempt since we're polling)
        let verified = await verifyPermissionViaScreenCaptureKit(maxAttempts: 1, delaySeconds: 0)
        if verified {
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
