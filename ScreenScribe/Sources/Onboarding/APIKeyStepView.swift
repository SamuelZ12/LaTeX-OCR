import SwiftUI

struct APIKeyStepView: View {
    @StateObject private var manager = OnboardingManager.shared
    @AppStorage("geminiAPIKey") private var apiKeyInput: String = ""
    @State private var isValidAPIKey: Bool = false

    private func validateAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.starts(with: "AIza") && trimmed.count == 39
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Set Up AI Features")
                .font(.system(size: 24, weight: .bold))

            Text("Enter your Google Gemini API key to enable AI-powered extraction for LaTeX, Markdown, and custom prompts.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            // API Key input
            VStack(spacing: 8) {
                HStack {
                    SecureField("Enter your API key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                        .onChange(of: apiKeyInput) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if newValue != trimmed {
                                apiKeyInput = trimmed
                            }
                            isValidAPIKey = validateAPIKey(trimmed)
                        }

                    if !apiKeyInput.isEmpty {
                        if isValidAPIKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }

                if !apiKeyInput.isEmpty && !isValidAPIKey {
                    Text("Invalid format. Key should start with 'AIza' and be 39 characters.")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Link("Get API Key from Google AI Studio", destination: URL(string: "https://makersuite.google.com/app/apikey")!)
                    .font(.caption)
            }
            .padding(.top, 8)

            Text("Text OCR works without an API key")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    manager.nextStep()
                }) {
                    Text("Skip for Now")
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
                .disabled(!isValidAPIKey)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 40)
        .onAppear {
            isValidAPIKey = validateAPIKey(apiKeyInput)
        }
    }
}

#Preview {
    APIKeyStepView()
}
