import SwiftUI

struct WelcomeStepView: View {
    @StateObject private var manager = OnboardingManager.shared
    @StateObject private var permissionManager = ScreenCapturePermissionManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("Welcome to ScreenScribe")
                .font(.system(size: 28, weight: .bold))

            Text("Capture any screen region and extract text, LaTeX, or Markdown using AI.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()

            Button(action: {
                // Skip permission step if already granted
                if permissionManager.hasPermission {
                    manager.goToStep(.apiKey)
                } else {
                    manager.nextStep()
                }
            }) {
                Text("Get Started")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    WelcomeStepView()
}
