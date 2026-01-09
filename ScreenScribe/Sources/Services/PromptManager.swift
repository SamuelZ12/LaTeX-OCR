import Foundation
import Combine

/// Manages prompts for AI-powered extraction, including built-in and custom prompts
@MainActor
final class PromptManager: ObservableObject {
    static let shared = PromptManager()

    private let customPromptsKey = "customPrompts"
    private let defaultPromptIdKey = "defaultPromptId"
    private let builtInCopyFormatsKey = "builtInPromptCopyFormats"

    @Published private(set) var prompts: [Prompt] = []
    @Published private(set) var defaultPrompt: Prompt = Prompt.latexPrompt

    private init() {
        loadPrompts()
        migrateOldSettings()
    }

    // MARK: - Loading

    private func loadPrompts() {
        // Start with built-in prompts
        var allPrompts = Prompt.defaultBuiltInPrompts

        // Load any saved copy format overrides for built-in prompts
        if let data = UserDefaults.standard.data(forKey: builtInCopyFormatsKey),
           let formats = try? JSONDecoder().decode([String: Prompt.CopyFormat].self, from: data) {
            for i in allPrompts.indices {
                if let format = formats[allPrompts[i].id.uuidString] {
                    allPrompts[i].copyFormat = format
                }
            }
        }

        // Load custom prompts
        if let data = UserDefaults.standard.data(forKey: customPromptsKey),
           let customPrompts = try? JSONDecoder().decode([Prompt].self, from: data) {
            allPrompts.append(contentsOf: customPrompts)
        }

        // Load default prompt ID
        if let defaultIdString = UserDefaults.standard.string(forKey: defaultPromptIdKey),
           let defaultId = UUID(uuidString: defaultIdString),
           let prompt = allPrompts.first(where: { $0.id == defaultId }) {
            // Mark the default prompt
            for i in allPrompts.indices {
                allPrompts[i].isDefault = (allPrompts[i].id == defaultId)
            }
            defaultPrompt = prompt
        } else {
            // Default to LaTeX prompt
            for i in allPrompts.indices {
                allPrompts[i].isDefault = (allPrompts[i].id == Prompt.latexPromptId)
            }
            defaultPrompt = allPrompts.first { $0.id == Prompt.latexPromptId } ?? Prompt.latexPrompt
        }

        prompts = allPrompts
    }

    // MARK: - Migration

    private func migrateOldSettings() {
        // Migrate old extractLatexCopyFormat to LaTeX prompt's copyFormat
        if let oldFormat = UserDefaults.standard.string(forKey: "extractLatexCopyFormat") {
            if let format = Prompt.CopyFormat(rawValue: oldFormat),
               let index = prompts.firstIndex(where: { $0.id == Prompt.latexPromptId }) {
                prompts[index].copyFormat = format
                if defaultPrompt.id == Prompt.latexPromptId {
                    defaultPrompt.copyFormat = format
                }
                saveBuiltInCopyFormats()
            }
            // Clean up old keys
            UserDefaults.standard.removeObject(forKey: "extractLatexCopyFormat")
            UserDefaults.standard.removeObject(forKey: "extractTextCopyFormat")
        }
    }

    // MARK: - CRUD Operations

    /// Add a new custom prompt
    func addPrompt(_ prompt: Prompt) {
        var newPrompt = prompt
        newPrompt.isDefault = false  // New prompts are not default by default
        prompts.append(newPrompt)
        saveCustomPrompts()
    }

    /// Update an existing prompt
    func updatePrompt(_ prompt: Prompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else { return }

        if prompts[index].isBuiltIn {
            // For built-in prompts, only allow updating copyFormat
            prompts[index].copyFormat = prompt.copyFormat
            saveBuiltInCopyFormats()
        } else {
            // For custom prompts, allow full updates
            prompts[index] = prompt
            prompts[index].isDefault = (defaultPrompt.id == prompt.id)
            saveCustomPrompts()
        }

        // Update defaultPrompt reference if this was the default
        if defaultPrompt.id == prompt.id {
            defaultPrompt = prompts[index]
        }
    }

    /// Delete a custom prompt (built-in prompts cannot be deleted)
    func deletePrompt(_ prompt: Prompt) {
        guard !prompt.isBuiltIn else { return }

        prompts.removeAll { $0.id == prompt.id }

        // If deleted prompt was default, revert to LaTeX
        if defaultPrompt.id == prompt.id {
            setDefaultPrompt(prompts.first { $0.id == Prompt.latexPromptId } ?? Prompt.latexPrompt)
        }

        saveCustomPrompts()
    }

    /// Set a prompt as the default
    func setDefaultPrompt(_ prompt: Prompt) {
        // Update isDefault flag for all prompts
        for i in prompts.indices {
            prompts[i].isDefault = (prompts[i].id == prompt.id)
        }

        // Update the stored default
        if let updatedPrompt = prompts.first(where: { $0.id == prompt.id }) {
            defaultPrompt = updatedPrompt
        } else {
            defaultPrompt = prompt
        }

        UserDefaults.standard.set(prompt.id.uuidString, forKey: defaultPromptIdKey)
    }

    // MARK: - Persistence

    private func saveCustomPrompts() {
        let customPrompts = prompts.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(customPrompts) {
            UserDefaults.standard.set(data, forKey: customPromptsKey)
        }
    }

    private func saveBuiltInCopyFormats() {
        var formats: [String: Prompt.CopyFormat] = [:]
        for prompt in prompts where prompt.isBuiltIn {
            formats[prompt.id.uuidString] = prompt.copyFormat
        }
        if let data = try? JSONEncoder().encode(formats) {
            UserDefaults.standard.set(data, forKey: builtInCopyFormatsKey)
        }
    }

    // MARK: - Convenience

    /// Get only custom (user-created) prompts
    var customPrompts: [Prompt] {
        prompts.filter { !$0.isBuiltIn }
    }

    /// Get only built-in prompts
    var builtInPrompts: [Prompt] {
        prompts.filter { $0.isBuiltIn }
    }

    /// Get a prompt by ID
    func prompt(byId id: UUID) -> Prompt? {
        prompts.first { $0.id == id }
    }
}
