import Foundation
import AppKit // Added for CGImage support

/// Represents possible errors that can occur during LaTeX API operations
enum LatexAPIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case parsingError
    case invalidAPIKey
}

/// Service responsible for handling LaTeX extraction API requests
@MainActor
public final class LatexAPIService {
    private let session: URLSession
    private let settingsManager: SettingsManager
    
    init(session: URLSession = .shared, settingsManager: SettingsManager = .shared) {
        self.session = session
        self.settingsManager = settingsManager
    }
    
    /// Extracts LaTeX from an image using Gemini API
    /// - Parameter base64Image: Base64 encoded image string
    /// - Returns: Extracted LaTeX string
    /// - Throws: LatexAPIError
    func extractLatex(from base64Image: String) async throws -> String {
        guard let apiKey = settingsManager.getGeminiApiKey(),
              !apiKey.isEmpty else {
            throw LatexAPIError.invalidAPIKey
        }
        
        let endpoint = "\(Config.geminiEndpoint)?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw LatexAPIError.invalidResponse
        }
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Convert the mathematical expression in this image to LaTeX code."],
                        ["inline_data": [
                            "mime_type": "image/png",
                            "data": base64Image
                        ]]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            guard let text = response.candidates.first?.content.parts.first?.text else {
                throw LatexAPIError.invalidResponse
            }
            
            return text
        } catch {
            throw LatexAPIError.networkError(error)
        }
    }
}

// MARK: - Response Types
private struct GeminiResponse: Codable {
    let candidates: [Candidate]
}

private struct Candidate: Codable {
    let content: Content
}

private struct Content: Codable {
    let parts: [Part]
}

private struct Part: Codable {
    let text: String
}
