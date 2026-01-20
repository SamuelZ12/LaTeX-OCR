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
        // Only use safe, read-only check on init
        // CGPreflightScreenCaptureAccess does NOT trigger any dialog
        hasPermission = CGPreflightScreenCaptureAccess()
        // Note: On macOS Sequoia, this may return false even when permission is granted
        // The verification via ScreenCaptureKit will happen when explicitly requested
        // via requestPermissionAndStartMonitoring()
    }

    /// Verify permission using ScreenCaptureKit with retry logic
    /// Returns true if permission is confirmed, false if all attempts fail
    /// On macOS Sequoia, ScreenCaptureKit can throw errors at app launch even when permission is granted
    /// This is a known issue where the system needs time to initialize screen capture subsystems
    private func verifyPermissionViaScreenCaptureKit(maxAttempts: Int = 5, delaySeconds: Double = 1.0) async -> Bool {
        for attempt in 1...maxAttempts {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                hasPermission = true
                stopPolling()
                Logger.log(.info, "ScreenCaptureKit permission verified on attempt \(attempt)")
                return true
            } catch let error as NSError {
                // Log known error codes that indicate permission is actually granted
                // but system is not ready yet (common on macOS Sequoia after restart)
                // Known transient errors: -3801 (userDeclined), -3802 (failedToStart),
                // -3803 (missingEntitlements), -3805 (systemStoppedStream)

                Logger.log(.info, "ScreenCaptureKit attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription) (domain: \(error.domain), code: \(error.code))")

                if attempt < maxAttempts {
                    // Use exponential backoff for better handling of slow system initialization
                    let delay = delaySeconds * Double(attempt)
                    Logger.log(.info, "Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                Logger.log(.info, "ScreenCaptureKit attempt \(attempt)/\(maxAttempts) failed with unexpected error: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    let delay = delaySeconds * Double(attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        return false
    }

    /// Request permission and start monitoring for changes
    func requestPermissionAndStartMonitoring() async {
        Logger.log(.info, "Starting permission request and monitoring...")

        // First, check via ScreenCaptureKit with retries (more reliable on macOS Sequoia)
        // CGPreflightScreenCaptureAccess can return false even when permission is granted
        // ScreenCaptureKit can also throw errors after restart/cold boot, so we retry with exponential backoff
        // Use more attempts (5) and longer base delay (1.0s) for initial check since we might be starting from cold boot
        let hasPermissionNow = await verifyPermissionViaScreenCaptureKit(maxAttempts: 5, delaySeconds: 1.0)

        // If already granted, no need to show dialog
        if hasPermissionNow {
            Logger.log(.info, "Permission already granted (verified via ScreenCaptureKit with retries)")
            return
        }

        // Also try CGPreflightScreenCaptureAccess as a final check before showing dialog
        // Sometimes it works even when ScreenCaptureKit fails
        if CGPreflightScreenCaptureAccess() {
            Logger.log(.info, "Permission detected via CGPreflightScreenCaptureAccess after ScreenCaptureKit failed")
            hasPermission = true
            return
        }

        // Only trigger the system permission dialog if truly not granted after all retry methods
        Logger.log(.info, "Permission not detected after retries, showing system dialog")
        let result = CGRequestScreenCaptureAccess()
        hasPermission = result

        // If not granted, start polling
        if !hasPermission {
            startPolling()
        }
    }

    /// Check permission status (read-only, does not trigger any dialogs)
    func checkPermission() -> Bool {
        // Only use the safe read-only API
        if CGPreflightScreenCaptureAccess() {
            hasPermission = true
            return true
        }
        // Return the cached value (may have been updated by prior ScreenCaptureKit verification)
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
                Logger.log(.info, "Screen capture permission granted (via CGPreflightScreenCaptureAccess)")
            }
            return
        }

        // Fallback: check via ScreenCaptureKit with a couple of attempts
        // On macOS Sequoia, permission detection can be flaky even during polling
        let verified = await verifyPermissionViaScreenCaptureKit(maxAttempts: 2, delaySeconds: 0.5)
        if verified {
            Logger.log(.info, "Screen capture permission granted (via ScreenCaptureKit polling)")
        }
    }

    /// Open System Settings to the Screen Recording pane
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
