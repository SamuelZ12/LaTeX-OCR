import SwiftUI
import Combine

struct PermissionStepView: View {
    @StateObject private var manager = OnboardingManager.shared
    @StateObject private var permissionManager = ScreenCapturePermissionManager.shared
    @State private var isCheckingPermission = false

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

            // Troubleshooting section
            VStack(alignment: .leading, spacing: 8) {
                Text("Troubleshooting:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text("If permission is not working:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 4) {
                        Text("1.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Open System Settings → Privacy & Security → Screen Recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 4) {
                        Text("2.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Remove ScreenScribe from the list")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 4) {
                        Text("3.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Quit ScreenScribe completely")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 4) {
                        Text("4.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Restart ScreenScribe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 4) {
                        Text("5.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Accept the permission when prompted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 4) {
                        Text("6.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Restart ScreenScribe again")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 8)
            }
            .frame(maxWidth: 360)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )

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
                    Task {
                        isCheckingPermission = true
                        await permissionManager.requestPermissionAndStartMonitoring()
                        isCheckingPermission = false
                    }
                }) {
                    Text("Recheck Permission")
                        .frame(width: 200)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(permissionManager.hasPermission || isCheckingPermission)

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
                Task {
                    await permissionManager.requestPermissionAndStartMonitoring()
                }
            }
        }
    }
}

#Preview {
    PermissionStepView()
}
