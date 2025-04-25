import Foundation

/// Represents possible errors that can occur during LaTeX API operations
enum LatexAPIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case parsingError
}

/// Service responsible for handling LaTeX extraction API requests
@MainActor
class LatexAPIService {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Extracts LaTeX from an image using Gemini API
    /// - Parameter imageBase64: Base64 encoded image string
    /// - Returns: Extracted LaTeX string
    /// - Throws: LatexAPIError
    func extractLatex(from imageBase64: String) async throws -> String {
        let payload: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": "Extract all mathematical expressions from this image and convert them to precise LaTeX notation. Carefully preserve all symbols, subscripts, superscripts, fractions, integrals, summations, and special characters. Ensure proper nesting of brackets and parentheses. For non-mathematical text, return it as plain text. Do not add any explanations, markdown formatting, or delimiters like $$ or ```latex. Return only the detected content with accurate LaTeX syntax."],
                    ["inline_data": [
                        "mime_type": "image/png",
                        "data": imageBase64
                    ]]
                ]
            ]]
        ]
        
        let apiKey = Config.geminiAPIKey
        guard !apiKey.isEmpty else {
            throw LatexAPIError.apiError("Gemini API key not set in Settings.")
        }
        
        guard let url = URL(string: "\(Config.geminiEndpoint)?key=\(apiKey)") else {
            throw LatexAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LatexAPIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw LatexAPIError.apiError(message)
                } else {
                    throw LatexAPIError.apiError("API request failed with status \(httpResponse.statusCode)")
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                throw LatexAPIError.parsingError
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as LatexAPIError {
            throw error
        } catch {
            throw LatexAPIError.networkError(error)
        }
    }
}
