import Foundation

/// Represents a customizable prompt for AI-powered extraction
struct Prompt: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var content: String
    var copyFormat: CopyFormat
    let isBuiltIn: Bool
    var isDefault: Bool
    let createdAt: Date

    enum CopyFormat: String, Codable, CaseIterable {
        case lineBreaks = "lineBreaks"
        case spaces = "spaces"
        case latexNewlines = "latexNewlines"

        var displayName: String {
            switch self {
            case .lineBreaks: return "Line Breaks"
            case .spaces: return "Spaces"
            case .latexNewlines: return "LaTeX \\\\"
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        content: String,
        copyFormat: CopyFormat = .lineBreaks,
        isBuiltIn: Bool = false,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.copyFormat = copyFormat
        self.isBuiltIn = isBuiltIn
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

// MARK: - Built-in Prompts

extension Prompt {
    /// Stable UUID for LaTeX built-in prompt
    static let latexPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Stable UUID for Markdown built-in prompt
    static let markdownPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static let latexPrompt = Prompt(
        id: latexPromptId,
        name: "LaTeX",
        content: """
            You are a specialized OCR engine that extracts text and mathematical notation from images with perfect accuracy. Your ONLY task is to process the provided image and output its content according to these strict rules:

            1. Convert all mathematical expressions and formulas into precise, syntactically correct LaTeX code. Preserve all symbols, subscripts, superscripts, fractions, integrals, matrices, alignments, and other mathematical structures.
            2. Extract all non-mathematical text as plain text. Critically analyze the layout: if a single sentence or paragraph of text is visually broken onto multiple lines solely due to spatial constraints or text wrapping within the image, you MUST join these lines with a single space to reconstruct the original coherent text block.
            3. Convert tables to proper LaTeX table format using the 'tabular' environment. Preserve column alignment (left, center, right), borders, and cell merging where applicable. Use appropriate LaTeX commands such as \\hline for horizontal lines and & for column separators. For complex tables with special formatting, include all necessary LaTeX commands to maintain the visual structure.
            4. For figures, diagrams, and other non-text elements: Include a brief descriptor in [square brackets] such as [FIGURE: brief description of content] where the figure appears in the document flow. Do not attempt to recreate complex diagrams textually.
            5. For handwritten content: Process clear handwritten text and equations to the best of your ability. If handwriting is present but illegible, indicate this with [ILLEGIBLE HANDWRITING] in the appropriate location. If partially legible, extract what you can and indicate uncertain portions with [?].

            IMPORTANT OUTPUT RULES:
            - DO NOT preserve existing LaTeX environments. Instead, convert all mathematical content to raw LaTeX commands without environment declarations.
            - DO NOT wrap LaTeX code in markdown fences (like ```latex).
            - Your entire response must consist solely of the extracted content.
            """,
        copyFormat: .lineBreaks,
        isBuiltIn: true,
        isDefault: true,
        createdAt: Date.distantPast
    )

    static let markdownPrompt = Prompt(
        id: markdownPromptId,
        name: "Markdown",
        content: """
            You are a specialized OCR engine that extracts content from images and converts it to clean Markdown format. Your task:

            1. Extract all text content and format it as proper Markdown.
            2. Convert headings to appropriate Markdown heading levels (# ## ###).
            3. Format lists as Markdown bullet points (-) or numbered lists (1. 2. 3.).
            4. Convert tables to Markdown table syntax with proper alignment.
            5. Preserve emphasis (bold with **, italic with *) where visible in the image.
            6. For mathematical expressions, wrap them in $...$ for inline or $$...$$ for block equations.
            7. For code blocks, use appropriate markdown fencing with language hints when identifiable.
            8. Preserve links and URLs as Markdown links [text](url) when visible.

            OUTPUT RULES:
            - Return only the extracted content in Markdown format.
            - Do not include explanations or commentary.
            - Do not wrap the output in additional markdown code fences.
            - Maintain the logical structure and hierarchy of the original content.
            """,
        copyFormat: .lineBreaks,
        isBuiltIn: true,
        isDefault: false,
        createdAt: Date.distantPast
    )

    /// Default built-in prompts that ship with the app
    static let defaultBuiltInPrompts: [Prompt] = [latexPrompt, markdownPrompt]
}
