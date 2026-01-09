import Foundation
import Combine

@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    private let hasCompletedKey = "hasCompletedOnboarding"
    private let versionKey = "onboardingVersion"
    private let currentVersion = 1

    @Published var currentStep: OnboardingStep = .welcome
    @Published var isOnboardingComplete: Bool = false

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case permission = 1
        case apiKey = 2
        case completion = 3
    }

    private init() {}

    var shouldShowOnboarding: Bool {
        let completed = UserDefaults.standard.bool(forKey: hasCompletedKey)
        let version = UserDefaults.standard.integer(forKey: versionKey)
        return !completed || version < currentVersion
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: hasCompletedKey)
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        isOnboardingComplete = true
    }

    func nextStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < OnboardingStep.allCases.count else {
            return
        }
        currentStep = OnboardingStep.allCases[currentIndex + 1]
    }

    func goToStep(_ step: OnboardingStep) {
        currentStep = step
    }

    func reset() {
        currentStep = .welcome
        isOnboardingComplete = false
    }
}
