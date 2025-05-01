import Foundation
import Carbon
import SwiftUI

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var textShortcut: ShortcutMonitor.KeyboardShortcut? {
        willSet {
            objectWillChange.send()
        }
        didSet {
            UserDefaults.standard.setCodable(textShortcut, forKey: "textShortcut")
            ShortcutMonitor.shared.setShortcut(textShortcut, for: .text)
        }
    }
    
    @Published var latexShortcut: ShortcutMonitor.KeyboardShortcut? {
        willSet {
            objectWillChange.send()
        }
        didSet {
            UserDefaults.standard.setCodable(latexShortcut, forKey: "latexShortcut")
            ShortcutMonitor.shared.setShortcut(latexShortcut, for: .latex)
        }
    }
    
    @Published var selectedModel: String {
        willSet {
            objectWillChange.send()
        }
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "geminiModel")
        }
    }
    
    @Published var extractTextCopyFormat: String {
        willSet {
            objectWillChange.send()
        }
        didSet {
            UserDefaults.standard.set(extractTextCopyFormat, forKey: "extractTextCopyFormat")
        }
    }
    
    @Published var extractLatexCopyFormat: String {
        willSet {
            objectWillChange.send()
        }
        didSet {
            UserDefaults.standard.set(extractLatexCopyFormat, forKey: "extractLatexCopyFormat")
        }
    }
    
    private init() {
        textShortcut = UserDefaults.standard.codable(forKey: "textShortcut")
        latexShortcut = UserDefaults.standard.codable(forKey: "latexShortcut")
        extractTextCopyFormat = UserDefaults.standard.string(forKey: "extractTextCopyFormat") ?? "lineBreaks"
        extractLatexCopyFormat = UserDefaults.standard.string(forKey: "extractLatexCopyFormat") ?? "lineBreaks"
        selectedModel = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.0-flash"
        
        if textShortcut == nil {
            textShortcut = ShortcutMonitor.KeyboardShortcut(
                keyCode: kVK_ANSI_T,
                modifiers: [.command]
            )
        }
        
        if latexShortcut == nil {
            latexShortcut = ShortcutMonitor.KeyboardShortcut(
                keyCode: kVK_ANSI_L,
                modifiers: [.command]
            )
        }

        ShortcutMonitor.shared.setShortcut(textShortcut, for: .text)
        ShortcutMonitor.shared.setShortcut(latexShortcut, for: .latex)
    }
}
