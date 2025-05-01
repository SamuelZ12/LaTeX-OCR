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
    private let maxRetries: Int
    private let initialDelay: UInt64
    
    init(session: URLSession = .shared, maxRetries: Int = 3, initialDelay: UInt64 = 1_000_000_000) {
        self.session = session
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
    }
    
    private func shouldRetry(statusCode: Int, error: Error?) -> Bool {
        // Implement retry logic here
        // For example:
        return statusCode >= 500 || error is URLError && (error as? URLError)?.code == .networkConnectionLost
    }
    
    func extractLatex(from base64Image: String, apiKey: String, format: String = "lineBreaks") async throws -> String {
        guard !apiKey.isEmpty else {
            throw LatexAPIError.apiKeyMissing
        }
        
        // Get the selected model from UserDefaults
        let model = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.0-flash"
        
        let lineSeparator = format == "latexNewlines" ? " \\\\\\\\ " : "\\n"
        
        // Define rules based on format
        let mathDelimiterRule = format == "latexNewlines" ?
            "- ALWAYS wrap mathematical expressions in $...$ for inline math or $$...$$ for display math based on the context. Inline formulas within text should use single $, while standalone formulas should use $$." :
            "- DO NOT add surrounding math delimiters like `$` or `$$` to the LaTeX code. Output the raw LaTeX commands for each formula."
        
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
                    ["text": """
                    You are a specialized OCR engine that extracts text and mathematical notation from images with perfect accuracy. Your ONLY task is to process the provided image and output its content according to these strict rules:

                    1. Convert all mathematical expressions and formulas into precise, syntactically correct LaTeX code. Preserve all symbols, subscripts, superscripts, fractions, integrals, matrices, alignments, and other mathematical structures.
                    2. Extract all non-mathematical text as plain text. Critically analyze the layout: if a single sentence or paragraph of text is visually broken onto multiple lines solely due to spatial constraints or text wrapping within the image, you MUST join these lines with a single space to reconstruct the original coherent text block. Do NOT insert '\(lineSeparator)' in such cases.
                    3. Convert tables to proper LaTeX table format using the 'tabular' environment. Preserve column alignment (left, center, right), borders, and cell merging where applicable. Use appropriate LaTeX commands such as \\hline for horizontal lines and & for column separators. For complex tables with special formatting, include all necessary LaTeX commands to maintain the visual structure.
                    4. For figures, diagrams, and other non-text elements: Include a brief descriptor in [square brackets] such as [FIGURE: brief description of content] where the figure appears in the document flow. Do not attempt to recreate complex diagrams textually.
                    5. For handwritten content: Process clear handwritten text and equations to the best of your ability. If handwriting is present but illegible, indicate this with [ILLEGIBLE HANDWRITING] in the appropriate location. If partially legible, extract what you can and indicate uncertain portions with [?].
                    6. Use '\(lineSeparator)' ONLY to separate genuinely distinct blocks of content.

                    Examples of distinct blocks include:
                    - Separate paragraphs of text
                    - Individual mathematical expressions that don't belong to a single multi-line structure (such as an align environment)
                    - A text block followed by a standalone mathematical formula (or vice-versa)
                    - Individual items within a list

                    IMPORTANT OUTPUT RULES:
                    \(mathDelimiterRule)
                    - DO NOT preserve existing LaTeX environments like \\\\begin{align}...\\\\end{align}. Instead, convert all mathematical content to raw LaTeX commands without environment declarations.
                    - DO NOT wrap LaTeX code in markdown fences (like ```latex).
                    - Your entire response must consist solely of the extracted content.
                    """
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0,
                "candidateCount": 1,
                "maxOutputTokens": 2048
            ]
        ]
        
        // Build URL with the specified model
        guard let url = URL(string: "\(Config.geminiEndpoint(for: model))?key=\(apiKey)") else {
            throw LatexAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        var retryCount = 0
        while retryCount <= maxRetries {
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
                if shouldRetry(statusCode: 0, error: error) {
                    retryCount += 1
                    try await Task.sleep(nanoseconds: initialDelay * UInt64(retryCount))
                } else {
                    throw LatexAPIError.networkError(error)
                }
            }
        }
        
        throw LatexAPIError.networkError(NSError(domain: "com.example.error", code: 0, userInfo: nil))
    }
}
