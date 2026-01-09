import AppKit
import ServiceManagement
import Foundation
import Carbon
import os.log
import CoreGraphics
import Combine

struct HistoryEntry: Codable {
    let text: String
    let type: ExtractionType
    let timestamp: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

@MainActor
class HistoryManager {
    static let shared = HistoryManager()
    private let maxEntries = 10
    private var entries: [HistoryEntry] = []
    
    func addEntry(_ text: String, type: ExtractionType) {
        let entry = HistoryEntry(text: text, type: type, timestamp: Date())
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast()
        }
    }
    
    func clearHistory() {
        entries.removeAll()
    }
    
    var recentEntries: [HistoryEntry] {
        return entries
    }
}

@MainActor
final class App: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var currentResult: Recognizer.ResultData?
    private var pasteboardObserver: Timer?
    private var pasteboardChangeCount = 0
    private var settingsWindowController: SettingsWindowController?
    private let settingsManager = SettingsManager.shared
    private let historyManager = HistoryManager.shared
    
    private var isExtracting = false
    private var originalStatusImage: NSImage?
    private var currentFeedbackTask: Task<Void, Never>?
    
    private lazy var extractTextItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleExtractText)
        item.addAction { [weak self] in
            self?.initiateCapture(for: .text)
        }
        return item
    }()

    private lazy var extractLatexItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleExtractLaTeX)
        item.addAction { [weak self] in
            self?.initiateCapture(for: .latex)
        }
        return item
    }()

    private lazy var settingsItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleSettings)
        item.addAction { [weak self] in
            self?.showSettings()
        }
        return item
    }()

    private lazy var quitItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleQuitTextGrabber2, action: nil, keyEquivalent: "q")
        item.keyEquivalentModifierMask = .command
        item.addAction {
            NSApp.terminate(nil)
        }
        return item
    }()

    private lazy var historyMenu: NSMenu = {
        let menu = NSMenu()
        return menu
    }()
    
    private lazy var historyItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleHistory)
        item.submenu = historyMenu
        return item
    }()
    
    private lazy var clearHistoryItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleClearHistory)
        item.addAction { [weak self] in
            self?.historyManager.clearHistory()
        }
        return item
    }()

    private lazy var statusItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = .terminationOnRemoval
        item.autosaveName = Bundle.main.bundleName
        item.button?.image = .with(symbolName: Icons.textViewFinder, pointSize: 15)

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(extractTextItem)
        menu.addItem(extractLatexItem)
        menu.addItem(.separator())
        menu.addItem(historyItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)

        item.menu = menu
        return item
    }()

    private let latexService = LatexAPIService()
    private static let soundPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aiff"

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menu (required even if empty)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        // Edit menu with standard items
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = NSMenu(title: "Edit")
        mainMenu.addItem(editMenuItem)

        let editMenu = editMenuItem.submenu!
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        NSApp.mainMenu = mainMenu
    }
    
    func statusItemInfo() -> (rect: CGRect, screen: NSScreen?)? {
        guard let button = statusItem.button, let window = button.window else {
            Logger.log(.error, "Missing button or window to provide positioning info")
            return nil
        }

        return (window.convertToScreen(button.frame), window.screen ?? .main)
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        guard CGPreflightScreenCaptureAccess() else {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "LaTeXOCR needs screen recording permission. Please grant access in System Settings."
            alert.alertStyle = .informational
            
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            NSApp.terminate(nil)
            return
        }

        clearMenuItems()
        statusItem.isVisible = true
        
        updateMenuItemKeyEquivalents()

        ShortcutMonitor.shared.startMonitoring { [weak self] type in
            self?.initiateCapture(for: type)
        }
        
        settingsManager.$textShortcut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItemKeyEquivalents()
            }
            .store(in: &cancellables)
        
        settingsManager.$latexShortcut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItemKeyEquivalents()
            }
            .store(in: &cancellables)
    }

    
    func applicationWillTerminate(_ notification: Notification) {
        ShortcutMonitor.shared.stopMonitoring()
    }

    @MainActor
    private func updateMenuItemKeyEquivalents() {
        if let shortcut = settingsManager.textShortcut {
            extractTextItem.keyEquivalent = shortcut.keyEquivalentCharacter
            extractTextItem.keyEquivalentModifierMask = shortcut.modifiers
        } else {
            extractTextItem.keyEquivalent = ""
            extractTextItem.keyEquivalentModifierMask = []
        }
        
        if let shortcut = settingsManager.latexShortcut {
            extractLatexItem.keyEquivalent = shortcut.keyEquivalentCharacter
            extractLatexItem.keyEquivalentModifierMask = shortcut.modifiers
        } else {
            extractLatexItem.keyEquivalent = ""
            extractLatexItem.keyEquivalentModifierMask = []
        }
    }

    @objc func menuWillOpen(_ menu: NSMenu) {
        extractLatexItem.isHidden = false
        extractTextItem.isHidden = false
        
        updateHistoryMenu()
        startDetection()
    }

    func menuDidClose(_ menu: NSMenu) {
        clearMenuItems()
    }

    func initiateCapture(for type: ExtractionType) {
        Task { @MainActor in
            await captureViaSystemUI()
            if let image = NSPasteboard.general.image {
                performExtraction(type: type, image: image)
            }
        }
    }
    
    private func captureViaSystemUI() async {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c", "-x"] // -i interactive, -c copy to clipboard, -x suppress sound
            task.terminationHandler = { _ in
                continuation.resume()
            }
            try? task.run()
        }
    }

    private func startDetection() {
        guard statusItem.menu != nil else {
            return Logger.assertFail("Missing menu to proceed")
        }

        currentResult = nil
        pasteboardChangeCount = NSPasteboard.general.changeCount

        if NSPasteboard.general.image?.cgImage != nil {
            extractLatexItem.isHidden = false
            extractTextItem.isHidden = false
        }
    }

    func showResult(_ resultData: Recognizer.ResultData, in menu: NSMenu) {
    }

    private func performExtraction(type: ExtractionType, image: NSImage?) {
        guard !isExtracting else {
            NSAlert.showModalAlert(message: "An extraction is already in progress. Please wait.")
            return
        }
        
        guard let image = image else {
            Logger.log(.error, "performExtraction called with no image for type \(type).")
            return
        }

        isExtracting = true

        switch type {
        case .text:
            Task {
                defer { isExtracting = false }
                
                guard let cgImage = image.cgImage else {
                    NSAlert.showModalAlert(message: "Failed to process image")
                    return
                }

                let result = await Recognizer.detect(image: cgImage, level: .accurate)
                let copyFormat = settingsManager.extractTextCopyFormat
                let textToCopy = copyFormat == "lineBreaks" ? result.lineBreaksJoined : result.spacesJoined

                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                let copied = pasteboard.setString(textToCopy, forType: .string)

                if copied {
                    showSuccessFeedback()
                    historyManager.addEntry(textToCopy, type: .text)
                }
            }

        case .latex:
            guard let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey"), !apiKey.isEmpty else {
                isExtracting = false
                NSAlert.showModalAlert(message: "Please set your Gemini API key in Settings")
                showSettings()
                return
            }

            guard let tiffData = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
                isExtracting = false
                Logger.log(.error, "Failed to convert image to PNG data for LaTeX extraction")
                NSAlert.showModalAlert(message: "Failed to process image data.")
                return
            }

            let base64Image = imageData.base64EncodedString()

            Task {
                defer { isExtracting = false }
                
                do {
                    let copyFormat = settingsManager.extractLatexCopyFormat
                    let latex = try await latexService.extractLatex(from: base64Image, apiKey: apiKey, format: copyFormat)
                    Logger.log(.info, "Raw LaTeX from API: \(latex)")
                    
                    let cleanedLatex = cleanLatexString(latex)
                    let textToCopy: String
                    
                    switch copyFormat {
                        case "spaces":
                            textToCopy = cleanedLatex.replacingOccurrences(of: "\n", with: " ")
                        default:
                            textToCopy = cleanedLatex
                    }
                    
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    Logger.log(.info, "Copied LaTeX to clipboard (format: \(copyFormat))")
                    showSuccessFeedback()
                    historyManager.addEntry(textToCopy, type: .latex)
                } catch let error as LatexAPIError {
                    handleLatexError(error)
                } catch {
                    NSAlert.showModalAlert(message: "Failed to extract LaTeX: \(error.localizedDescription)")
                    Logger.log(.error, "LaTeX extraction failed: \(error)")
                }
            }
        }
    }

    private func cleanLatexString(_ rawString: String) -> String {
        let cleaned = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    func showSuccessFeedback() {
        // Cancel any existing feedback task
        currentFeedbackTask?.cancel()
        
        // Play screenshot sound
        if let soundURL = Bundle.main.url(forResource: "Screen Capture", withExtension: "aif"),
           let screenshotSound = NSSound(contentsOf: soundURL, byReference: true) {
            screenshotSound.play()
        } else {
            Logger.log(.error, "Could not load screenshot sound file from app bundle")
        }
        
        // Update status item icon with proper state management
        if let button = self.statusItem.button {
            if originalStatusImage == nil {
                originalStatusImage = button.image
            }
            button.image = .with(symbolName: Icons.checkmark, pointSize: 15)
            
            // Create new feedback restoration task
            currentFeedbackTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                if !Task.isCancelled, let self = self {
                    button.image = self.originalStatusImage
                }
            }
        }
    }

    private func handleLatexError(_ error: LatexAPIError) {
        switch error {
        case .apiKeyMissing:
            NSAlert.showModalAlert(message: "Gemini API key is missing. Please set it in Settings.")
            showSettings()
        case .apiKeyInvalid:
            NSAlert.showModalAlert(message: "Invalid Gemini API key. Please check Settings.")
            showSettings()
        case .apiError(let message):
            NSAlert.showModalAlert(message: "Gemini API Error: \(message)")
        case .requestFailed(let error):
            NSAlert.showModalAlert(message: "Network request failed: \(error.localizedDescription)")
        case .invalidResponse:
            NSAlert.showModalAlert(message: "Received an invalid response from the API.")
        case .imageProcessingFailed:
            NSAlert.showModalAlert(message: "Failed to process image data for API request.")
        case .networkError(let error):
            NSAlert.showModalAlert(message: "Network error: \(error.localizedDescription)")
        case .parsingError:
            NSAlert.showModalAlert(message: "Failed to parse the API response.")
        }
        Logger.log(.error, "LaTeX extraction failed: \(error)")
    }

    private func updateHistoryMenu() {
        historyMenu.removeAllItems()
        
        let entries = historyManager.recentEntries
        if entries.isEmpty {
            let emptyItem = NSMenuItem(title: Localized.menuTitleNoHistory)
            emptyItem.isEnabled = false
            historyMenu.addItem(emptyItem)
        } else {
            for entry in entries {
                let menuItem = NSMenuItem(
                    title: "\(entry.formattedDate) - \(entry.type == .text ? "Text" : "LaTeX")",
                    action: nil,
                    keyEquivalent: ""
                )
                
                let submenu = NSMenu()
                let previewItem = NSMenuItem(title: entry.text.prefix(50) + "...", action: nil, keyEquivalent: "")
                previewItem.isEnabled = false
                submenu.addItem(previewItem)
                submenu.addItem(.separator())
                
                let copyItem = NSMenuItem(title: Localized.menuTitleCopy)
                copyItem.addAction { [weak self] in
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    self?.showSuccessFeedback()
                }
                submenu.addItem(copyItem)
                
                menuItem.submenu = submenu
                historyMenu.addItem(menuItem)
            }
            
            historyMenu.addItem(.separator())
            historyMenu.addItem(clearHistoryItem)
        }
    }

    private func clearMenuItems() {
        extractLatexItem.isHidden = true
    }
}

extension App: NSMenuDelegate {
    // No duplicate methods here - they're already defined in the main class
}

enum ExtractionType: String, Codable {
    case text
    case latex
}

extension NSAlert {
    static func showModalAlert(message: String, informativeText: String = "") {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
