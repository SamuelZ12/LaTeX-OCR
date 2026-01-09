import SwiftUI
import Combine

struct PermissionStepView: View {
    @StateObject private var manager = OnboardingManager.shared
    @StateObject private var permissionManager = ScreenCapturePermissionManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Screen Recording Permission")
                .font(.system(size: 24, weight: .bold))

            Text("ScreenScribe needs screen recording permission to capture screen regions for text extraction.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            // Status indicator
            HStack(spacing: 8) {
                if permissionManager.hasPermission {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Permission Granted")
                        .foregroundColor(.green)
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for Permission...")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    permissionManager.openSystemSettings()
                }) {
                    Text("Open System Settings")
                        .frame(width: 200)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: {
                    manager.nextStep()
                }) {
                    Text("Continue")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!permissionManager.hasPermission)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 40)
        .onAppear {
            // Start monitoring for permission if not already granted
            if !permissionManager.hasPermission {
                permissionManager.requestPermissionAndStartMonitoring()
            }
        }
    }
}

#Preview {
    PermissionStepView()
}
