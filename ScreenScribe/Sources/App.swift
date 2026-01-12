import AppKit
import ServiceManagement
import Foundation
import Carbon
import os.log
import CoreGraphics
import Combine

struct HistoryEntry: Codable {
    let text: String
    let promptId: UUID?        // nil for Vision OCR
    let promptName: String     // "Text (OCR)" or prompt name
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

    func addEntry(_ text: String, promptId: UUID?, promptName: String) {
        let entry = HistoryEntry(text: text, promptId: promptId, promptName: promptName, timestamp: Date())
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
    private var onboardingWindowController: OnboardingWindowController?
    private let settingsManager = SettingsManager.shared
    private let onboardingManager = OnboardingManager.shared
    private let historyManager = HistoryManager.shared
    private let promptManager = PromptManager.shared
    private lazy var permissionManager = ScreenCapturePermissionManager.shared

    private var isExtracting = false
    private var isFullySetup = false
    private var originalStatusImage: NSImage?
    private var currentFeedbackTask: Task<Void, Never>?

    private lazy var extractTextItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleExtractText)
        item.addAction { [weak self] in
            self?.initiateCaptureForText()
        }
        return item
    }()

    private var promptMenuItems: [NSMenuItem] = []

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

    private var statusItemMenu: NSMenu?

    private lazy var statusItem: NSStatusItem = {
        Logger.log(.info, "Creating status item...")
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = .terminationOnRemoval
        // Temporarily disabled autosaveName to rule out caching issues after project rename
        // item.autosaveName = Bundle.main.bundleName
        item.button?.image = .with(symbolName: Icons.textViewFinder, pointSize: 15)
        Logger.log(.info, "Status item button: \(String(describing: item.button)), image: \(String(describing: item.button?.image))")

        let menu = NSMenu()
        menu.delegate = self
        statusItemMenu = menu

        rebuildMenu()

        item.menu = menu
        return item
    }()

    private let geminiService = GeminiService()
    private static let soundPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aiff"

    private func rebuildMenu() {
        guard let menu = statusItemMenu else { return }
        menu.removeAllItems()

        // Extract Text (Vision OCR)
        menu.addItem(extractTextItem)
        menu.addItem(.separator())

        // Prompts section
        promptMenuItems.removeAll()
        for prompt in promptManager.prompts {
            let item = NSMenuItem(title: prompt.name)
            if prompt.isDefault {
                item.state = .on
            }
            item.addAction { [weak self] in
                self?.initiateCapture(with: prompt)
            }
            promptMenuItems.append(item)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(historyItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)

        updateMenuItemKeyEquivalents()
    }

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
        Logger.log(.info, "applicationDidFinishLaunching started")
        setupMainMenu()

        // Always show the status item
        Logger.log(.info, "About to access statusItem.isVisible")
        statusItem.isVisible = true
        Logger.log(.info, "Status item isVisible set to true, actual value: \(self.statusItem.isVisible)")
        Logger.log(.info, "Status item button exists: \(self.statusItem.button != nil)")

        // Check if onboarding is needed
        Logger.log(.info, "shouldShowOnboarding: \(self.onboardingManager.shouldShowOnboarding)")
        if onboardingManager.shouldShowOnboarding {
            Logger.log(.info, "Showing onboarding")
            showOnboarding()
            return
        }

        // Normal startup flow (no onboarding needed)
        Logger.log(.info, "Proceeding with normal startup")
        proceedWithNormalStartup()
    }

    /// Show the onboarding wizard for first-time users
    private func showOnboarding() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController()
        }
        onboardingWindowController?.showWindow(nil)

        // Subscribe to onboarding completion
        onboardingManager.$isOnboardingComplete
            .filter { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.onboardingWindowController?.close()
                self?.onboardingWindowController = nil
                self?.proceedWithNormalStartup()
            }
            .store(in: &cancellables)
    }

    /// Normal startup procedure (called after onboarding or directly if not needed)
    private func proceedWithNormalStartup() {
        // Check permission status
        if !permissionManager.checkPermission() {
            // Request permission (triggers system dialog) and start polling
            Task {
                await permissionManager.requestPermissionAndStartMonitoring()
            }

            // Update menu to show limited state
            updateMenuForLimitedState()
        } else {
            // Permission already granted, proceed normally
            setupFullFunctionality()
        }

        // Subscribe to permission changes
        permissionManager.$hasPermission
            .dropFirst() // Skip the initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                if granted {
                    self?.onPermissionGranted()
                }
            }
            .store(in: &cancellables)

        // Observe prompt changes to rebuild menu (needed regardless of permission)
        promptManager.$prompts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        promptManager.$defaultPrompt
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }


    func applicationWillTerminate(_ notification: Notification) {
        ShortcutMonitor.shared.stopMonitoring()
        permissionManager.stopPolling()
    }

    // MARK: - Permission Handling

    /// Show a clean, minimal alert explaining the permission requirement
    private func showPermissionRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = Localized.permissionAlertTitle
        alert.informativeText = Localized.permissionAlertMessage
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Open System Settings")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            permissionManager.openSystemSettings()
        }
    }

    /// Update menu items to reflect limited state (no capture ability)
    private func updateMenuForLimitedState() {
        extractTextItem.isEnabled = false
        extractTextItem.title = Localized.menuTitleExtractText + Localized.permissionRequired

        for item in promptMenuItems {
            item.isEnabled = false
        }
    }

    /// Called when permission is granted (either immediately or after polling)
    private func onPermissionGranted() {
        // Restore menu items
        extractTextItem.isEnabled = true
        extractTextItem.title = Localized.menuTitleExtractText

        for item in promptMenuItems {
            item.isEnabled = true
        }

        // Setup full functionality if not already done
        setupFullFunctionality()
    }

    /// Setup shortcuts and observers (called after permission granted)
    private func setupFullFunctionality() {
        guard !isFullySetup else { return }
        isFullySetup = true

        updateMenuItemKeyEquivalents()

        ShortcutMonitor.shared.startMonitoring { [weak self] action in
            switch action {
            case .visionOCR:
                self?.initiateCaptureForText()
            case .defaultPrompt:
                self?.initiateCapture(with: PromptManager.shared.defaultPrompt)
            }
        }

        settingsManager.$textShortcut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItemKeyEquivalents()
            }
            .store(in: &cancellables)

        settingsManager.$defaultPromptShortcut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuItemKeyEquivalents()
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func updateMenuItemKeyEquivalents() {
        // Text shortcut
        if let shortcut = settingsManager.textShortcut {
            extractTextItem.keyEquivalent = shortcut.keyEquivalentCharacter
            extractTextItem.keyEquivalentModifierMask = shortcut.modifiers
        } else {
            extractTextItem.keyEquivalent = ""
            extractTextItem.keyEquivalentModifierMask = []
        }

        // Default prompt shortcut - apply to the default prompt's menu item
        let defaultPromptId = promptManager.defaultPrompt.id
        for (index, prompt) in promptManager.prompts.enumerated() {
            guard index < promptMenuItems.count else { continue }
            let item = promptMenuItems[index]

            if prompt.id == defaultPromptId {
                item.state = .on
                if let shortcut = settingsManager.defaultPromptShortcut {
                    item.keyEquivalent = shortcut.keyEquivalentCharacter
                    item.keyEquivalentModifierMask = shortcut.modifiers
                } else {
                    item.keyEquivalent = ""
                    item.keyEquivalentModifierMask = []
                }
            } else {
                item.state = .off
                item.keyEquivalent = ""
                item.keyEquivalentModifierMask = []
            }
        }
    }

    @objc func menuWillOpen(_ menu: NSMenu) {
        updateHistoryMenu()
        startDetection()
    }

    func menuDidClose(_ menu: NSMenu) {
    }

    // MARK: - Capture Methods

    /// Initiate capture for Vision OCR (text extraction)
    func initiateCaptureForText() {
        Task { @MainActor in
            await captureViaSystemUI()
            if let image = NSPasteboard.general.image {
                performVisionExtraction(image: image)
            }
        }
    }

    /// Initiate capture with a specific prompt
    func initiateCapture(with prompt: Prompt) {
        Task { @MainActor in
            await captureViaSystemUI()
            if let image = NSPasteboard.general.image {
                performAIExtraction(image: image, prompt: prompt)
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
    }

    func showResult(_ resultData: Recognizer.ResultData, in menu: NSMenu) {
    }

    // MARK: - Extraction Methods

    /// Perform Vision OCR extraction (offline, text only)
    private func performVisionExtraction(image: NSImage) {
        guard !isExtracting else {
            NSAlert.showModalAlert(message: "An extraction is already in progress. Please wait.")
            return
        }

        isExtracting = true

        Task {
            defer { isExtracting = false }

            guard let cgImage = image.cgImage else {
                NSAlert.showModalAlert(message: "Failed to process image")
                return
            }

            let result = await Recognizer.detect(image: cgImage, level: .accurate)
            // For Vision OCR, always use line breaks format
            let textToCopy = result.lineBreaksJoined

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let copied = pasteboard.setString(textToCopy, forType: .string)

            if copied {
                showSuccessFeedback()
                historyManager.addEntry(textToCopy, promptId: nil, promptName: "Text (OCR)")
            }
        }
    }

    /// Perform AI extraction using a prompt
    private func performAIExtraction(image: NSImage, prompt: Prompt) {
        guard !isExtracting else {
            NSAlert.showModalAlert(message: "An extraction is already in progress. Please wait.")
            return
        }

        guard let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey"), !apiKey.isEmpty else {
            NSAlert.showModalAlert(message: "Please set your Gemini API key in Settings")
            showSettings()
            return
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
            Logger.log(.error, "Failed to convert image to PNG data for extraction")
            NSAlert.showModalAlert(message: "Failed to process image data.")
            return
        }

        let base64Image = imageData.base64EncodedString()

        isExtracting = true

        Task {
            defer { isExtracting = false }

            do {
                let extractedContent = try await geminiService.extractContent(
                    from: base64Image,
                    apiKey: apiKey,
                    promptContent: prompt.content
                )
                Logger.log(.info, "Raw content from API: \(extractedContent)")

                let cleanedContent = cleanExtractedString(extractedContent)
                let textToCopy: String

                // Apply copy format based on prompt settings
                switch prompt.copyFormat {
                case .spaces:
                    textToCopy = cleanedContent.replacingOccurrences(of: "\n", with: " ")
                case .latexNewlines:
                    textToCopy = cleanedContent.replacingOccurrences(of: "\n", with: " \\\\\n")
                case .lineBreaks:
                    textToCopy = cleanedContent
                }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToCopy, forType: .string)
                Logger.log(.info, "Copied content to clipboard (format: \(prompt.copyFormat.rawValue))")
                showSuccessFeedback()
                historyManager.addEntry(textToCopy, promptId: prompt.id, promptName: prompt.name)
            } catch let error as GeminiAPIError {
                handleGeminiError(error)
            } catch {
                NSAlert.showModalAlert(message: "Failed to extract content: \(error.localizedDescription)")
                Logger.log(.error, "Extraction failed: \(error)")
            }
        }
    }

    private func cleanExtractedString(_ rawString: String) -> String {
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

    private func handleGeminiError(_ error: GeminiAPIError) {
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
        Logger.log(.error, "Extraction failed: \(error)")
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
                    title: "\(entry.formattedDate) - \(entry.promptName)",
                    action: nil,
                    keyEquivalent: ""
                )

                let submenu = NSMenu()
                let previewText = entry.text.prefix(50)
                let previewItem = NSMenuItem(title: previewText + (entry.text.count > 50 ? "..." : ""), action: nil, keyEquivalent: "")
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
}

extension App: NSMenuDelegate {
    // No duplicate methods here - they're already defined in the main class
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
