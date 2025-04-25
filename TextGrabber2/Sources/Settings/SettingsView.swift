import SwiftUI

/// A view that displays and manages application settings
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showInvalidKeyAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            apiKeySection
            Divider()
            joinMethodsSection
            Divider()
            shortcutsSection
        }
        .padding()
        .frame(width: 400)
        .alert("Invalid API Key", isPresented: $showInvalidKeyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid Gemini API key")
        }
    }
    
    private var apiKeySection: some View {
        VStack(alignment: .leading) {
            Text("Gemini API Key")
                .font(.headline)
            SecureField("Enter API Key", text: $viewModel.apiKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.apiKey) { oldValue, newValue in
                    if !viewModel.validateApiKey(newValue) {
                        showInvalidKeyAlert = true
                    }
                }
        }
    }
    
    private var joinMethodsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Join Methods")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Vision Text")
                    .font(.subheadline)
                Picker("", selection: $viewModel.visionJoinMethod) {
                    ForEach(SettingsManager.JoinMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading) {
                Text("LaTeX Text")
                    .font(.subheadline)
                Picker("", selection: $viewModel.latexJoinMethod) {
                    ForEach(SettingsManager.JoinMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            
            HStack {
                Text("Vision Extraction:")
                TextField("Type shortcut", text: $viewModel.visionShortcut)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("LaTeX Extraction:")
                TextField("Type shortcut", text: $viewModel.latexShortcut)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

/// ViewModel for managing settings state and validation
class SettingsViewModel: ObservableObject {
    @Published var apiKey: String {
        didSet {
            if validateApiKey(apiKey) {
                SettingsManager.shared.setGeminiApiKey(apiKey)
            }
        }
    }
    
    @Published var visionJoinMethod: SettingsManager.JoinMethod {
        didSet {
            SettingsManager.shared.visionJoinMethod = visionJoinMethod
        }
    }
    
    @Published var latexJoinMethod: SettingsManager.JoinMethod {
        didSet {
            SettingsManager.shared.latexJoinMethod = latexJoinMethod
        }
    }
    
    @Published var visionShortcut: String {
        didSet {
            SettingsManager.shared.setShortcut(visionShortcut, forType: "visionShortcut")
        }
    }
    
    @Published var latexShortcut: String {
        didSet {
            SettingsManager.shared.setShortcut(latexShortcut, forType: "latexShortcut")
        }
    }
    
    init() {
        self.apiKey = SettingsManager.shared.getGeminiApiKey() ?? ""
        self.visionJoinMethod = SettingsManager.shared.visionJoinMethod
        self.latexJoinMethod = SettingsManager.shared.latexJoinMethod
        self.visionShortcut = SettingsManager.shared.getShortcut(forType: "visionShortcut") ?? ""
        self.latexShortcut = SettingsManager.shared.getShortcut(forType: "latexShortcut") ?? ""
    }
    
    /// Validates the Gemini API key format
    /// - Parameter key: The API key to validate
    /// - Returns: True if the key appears valid
    func validateApiKey(_ key: String) -> Bool {
        // Basic validation: Gemini API keys are typically non-empty strings
        // Add more specific validation if needed
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
