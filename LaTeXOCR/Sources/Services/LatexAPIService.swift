import Foundation

/// Represents possible errors that can occur during LaTeX API operations
enum LatexAPIError: Error, LocalizedError {
    case apiKeyMissing
    case apiKeyInvalid
    case apiError(String)
    case requestFailed(Error)
    case invalidResponse
    case imageProcessingFailed
    case networkError(Error)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Missing API key"
        case .apiKeyInvalid:
            return "Invalid API key"
        case .apiError(let message):
            return "API Error: \(message)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse response"
        }
    }
}

/// Service responsible for handling LaTeX extraction API requests
@MainActor
struct LatexAPIService {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Extracts LaTeX from an image using Gemini API
    /// - Parameter base64Image: Base64 encoded image string
    /// - Parameter apiKey: API key for Gemini API
    /// - Returns: Extracted LaTeX string
    /// - Throws: LatexAPIError
    func extractLatex(from base64Image: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw LatexAPIError.apiKeyMissing
        }
        
        let payload: [String: Any] = [
            "contents": [[
                "parts": [
                    ["inline_data": [
                        "mime_type": "image/png",
                        "data": base64Image
                    ]]
                ]
            ]],
            "systemInstruction": [
                "parts": [
                    ["text": "You are a specialized OCR engine that extracts text and mathematical notation from images with perfect accuracy. Your ONLY task is to process the provided image and output its content according to these strict rules:\n\n1. Convert all mathematical expressions and formulas into precise, syntactically correct LaTeX code. Preserve all symbols, subscripts, superscripts, fractions, integrals, matrices, alignments, and other mathematical structures.\n2. Extract all non-mathematical text as plain text. Critically analyze the layout: If a single sentence or paragraph of text is visually broken onto multiple lines solely due to spatial constraints or text wrapping within the image, you MUST join these lines with a single space to reconstruct the original coherent text block. Do NOT insert a newline character in such cases.\n3. Convert tables to proper LaTeX table format using the 'tabular' environment. Preserve column alignment (left, center, right), borders, and cell merging where applicable. Use appropriate LaTeX commands such as \\hline for horizontal lines and & for column separators. For complex tables with special formatting, include all necessary LaTeX commands to maintain the visual structure.\n4. For figures, diagrams, and other non-text elements: Include a brief descriptor in [square brackets] such as [FIGURE: brief description of content] where the figure appears in the document flow. Do not attempt to recreate complex diagrams textually.\n5. For handwritten content: Process clear handwritten text and equations to the best of your ability. If handwriting is present but illegible, indicate this with [ILLEGIBLE HANDWRITING] in the appropriate location. If partially legible, extract what you can and indicate uncertain portions with [?].\n6. Use newline characters ONLY to separate genuinely distinct blocks of content.\n\nExamples of distinct blocks include:\n- Separate paragraphs of text\n- Individual mathematical expressions that don't belong to a single multi-line structure (such as an align environment)\n- A text block followed by a standalone mathematical formula (or vice-versa)\n- Individual items within a list\n\nCRITICAL OUTPUT RULES:\n- DO NOT wrap LaTeX code in markdown fences (like ```latex).\n- DO NOT add surrounding math delimiters like `$` or `$$` to the LaTeX code. Output the raw LaTeX commands for each formula.\n- DO NOT preserve existing LaTeX environments like \\begin{align}...\\end{align}. Instead, convert all mathematical content to raw LaTeX commands without environment declarations.\n- EXCEPTION: The 'tabular' environment IS permitted for tables as specified in rule 3.\n- Your entire response must consist solely of the extracted content."]
                ]
            ],
            "generationConfig": [
                "temperature": 0,
                "candidateCount": 1,
                "maxOutputTokens": 2048
            ]
        ]
        
        guard let url = URL(string: "\(Config.geminiEndpoint)?key=\(apiKey)") else {
            throw LatexAPIError.invalidResponse
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
