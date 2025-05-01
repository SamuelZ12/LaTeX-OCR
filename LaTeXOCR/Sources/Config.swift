import Foundation

/// Manages loading and accessing configuration values from Secrets.plist

struct ConfigurationManager {
    @MainActor
    static let shared = ConfigurationManager()
    
    private let secrets: [String: String]
    
    private init() {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
            self.secrets = dict
        } else {
            print("Error: Could not load Secrets.plist. Please ensure it exists with a GEMINI_API_KEY entry.")
            self.secrets = [:]
        }
    }
    
    func getValue(for key: String) -> String? {
        return secrets[key]
    }
    
    func value(for key: String) -> String? {
        return getValue(for: key)
    }
}

/// Model structure for Gemini AI models
struct GeminiModel: Identifiable {
    let id: String      // raw id used in the URL
    let label: String   // shown to the user
    let note: String?   // optional footnote (speed / cost)
}

/// Central configuration access point for the application
enum Config {
    /// The Gemini API key loaded from Keychain or Secrets.plist
    @MainActor
    static var geminiAPIKey: String {
        if let key = UserDefaults.standard.string(forKey: "geminiAPIKey"), !key.isEmpty {
            return key
        }
        return ConfigurationManager.shared.value(for: "GEMINI_API_KEY") ?? ""
    }
    
    /// Available Gemini models to choose from
    static let availableGeminiModels: [GeminiModel] = [
        .init(id: "gemini-2.5-flash-preview-04-17", label: "Gemini 2.5 Flash Preview", note: nil),
        .init(id: "gemini-2.5-pro-exp-03-25", label: "Gemini 2.5 Pro Experimental", note: nil),
        .init(id: "gemini-2.0-flash", label: "Gemini 2.0 Flash", note: nil),
        .init(id: "gemini-2.0-flash-lite", label: "Gemini 2.0 Flash-Lite", note: nil),
        .init(id: "gemini-1.5-pro", label: "Gemini 1.5 Pro", note: nil),
        .init(id: "gemini-1.5-flash", label: "Gemini 1.5 Flash", note: nil)
    ]
    
    /// Get the Gemini API endpoint for the specified model
    static func geminiEndpoint(for model: String) -> String {
        return "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    }
}
