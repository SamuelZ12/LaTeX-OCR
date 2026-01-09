import SwiftUI

struct CompletionStepView: View {
    @StateObject private var manager = OnboardingManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.system(size: 24, weight: .bold))

            Text("Here's how to get started:")
                .font(.body)
                .foregroundColor(.secondary)

            // Quick tips
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "cursorarrow.click.2", text: "Click the menu bar icon to capture")
                TipRow(icon: "command", text: "Use Cmd+T for quick text extraction")
                TipRow(icon: "command", text: "Use Cmd+L for your default AI prompt")
                TipRow(icon: "gearshape", text: "Open Settings anytime to customize")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Spacer()

            Button(action: {
                manager.completeOnboarding()
            }) {
                Text("Start Using LaTeX OCR")
                    .frame(width: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 40)
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    CompletionStepView()
}
