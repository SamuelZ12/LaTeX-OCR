import SwiftUI

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager.shared
    @StateObject private var permissionManager = ScreenCapturePermissionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            ProgressIndicator(currentStep: manager.currentStep)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Group {
                switch manager.currentStep {
                case .welcome:
                    WelcomeStepView()
                case .permission:
                    PermissionStepView()
                case .apiKey:
                    APIKeyStepView()
                case .completion:
                    CompletionStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 480)
        .onAppear {
            // Skip permission step if already granted
            if manager.currentStep == .welcome && permissionManager.hasPermission {
                // Will skip permission step when user clicks "Get Started"
            }
        }
    }
}

struct ProgressIndicator: View {
    let currentStep: OnboardingManager.OnboardingStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingManager.OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
