//
//  App.swift
//  TextGrabber2
//
//  Created by cyan on 2024/3/20.
//

import AppKit
import ServiceManagement
import Foundation
import Carbon
import os.log

@MainActor
final class App: NSObject, NSApplicationDelegate {
    private var currentResult: Recognizer.ResultData?
    private var pasteboardObserver: Timer?
    private var pasteboardChangeCount = 0
    private var settingsWindowController: SettingsWindowController?
    private let settingsManager = SettingsManager.shared

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
        menu.addItem(settingsItem)
        menu.addItem(quitItem)

        item.menu = menu
        return item
    }()

    private let latexService = LatexAPIService()
    
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
        Services.initialize()
        clearMenuItems()
        statusItem.isVisible = true

        ShortcutMonitor.shared.startMonitoring { [weak self] type in
            self?.initiateCapture(for: type)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ShortcutMonitor.shared.stopMonitoring()
    }

    @objc func menuWillOpen(_ menu: NSMenu) {
        extractLatexItem.isHidden = true
        extractTextItem.isHidden = true  // Hide both items initially
        
        if NSPasteboard.general.image?.cgImage != nil {
            extractLatexItem.isHidden = false
            extractTextItem.isHidden = false  // Show both items if image exists
        }
        
        startDetection()
    }

    func menuDidClose(_ menu: NSMenu) {
        clearMenuItems()
    }

    func initiateCapture(for type: ExtractionType) {
        Task { @MainActor in
            if let image = await captureScreenRegion() {
                performExtraction(type: type, image: image)
            }
        }
    }
    
    private func captureScreenRegion() async -> NSImage? {
        guard let image = NSPasteboard.general.image else {
            NSAlert.showModalAlert(
                message: "No image found in clipboard",
                informativeText: "Please take a screenshot first (Cmd+Shift+4) before using the extract shortcut."
            )
            return nil
        }
        return image
    }

    private func startDetection() {
        guard let menu = statusItem.menu else {
            return Logger.assertFail("Missing menu to proceed")
        }

        currentResult = nil
        pasteboardChangeCount = NSPasteboard.general.changeCount

        guard let image = NSPasteboard.general.image?.cgImage else {
            return Logger.log(.info, "No image was copied")
        }

        extractLatexItem.isHidden = false // Show when image is present
        extractTextItem.isHidden = false // Show when image is present

        Task {
            let fastResult = await Recognizer.detect(image: image, level: .fast)
            self.showResult(fastResult, in: menu)

            let accurateResult = await Recognizer.detect(image: image, level: .accurate)
            self.showResult(accurateResult, in: menu)
        }
    }

    func showResult(_ resultData: Recognizer.ResultData, in menu: NSMenu) {
        guard currentResult != resultData else {
            #if DEBUG
                Logger.log(.debug, "No change in result data")
            #endif
            return
        }

        currentResult = resultData

        let separator = NSMenuItem.separator()
        menu.insertItem(separator, at: 0)
        menu.removeItems { $0 is ResultItem }

        for text in resultData.candidates.reversed() {
            let item = ResultItem(title: text)
            item.addAction { NSPasteboard.general.string = text }
            menu.insertItem(item, at: menu.index(of: separator) + 1)
        }
    }

    func performExtraction(type: ExtractionType, image: NSImage?) {
        guard let image = image else {
            Logger.log(.error, "performExtraction called with no image for type \(type).")
            return
        }

        switch type {
        case .text:
            Task {
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

                    guard let menu = statusItem.menu else { return }
                    showResult(result, in: menu)
                }
            }

        case .latex:
            guard let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey"), !apiKey.isEmpty else {
                NSAlert.showModalAlert(message: "Please set your Gemini API key in Settings")
                showSettings()
                return
            }

            guard let tiffData = image.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
                Logger.log(.error, "Failed to convert image to PNG data for LaTeX extraction")
                NSAlert.showModalAlert(message: "Failed to process image data.")
                return
            }

            let base64Image = imageData.base64EncodedString()

            Task {
                do {
                    let latex = try await latexService.extractLatex(from: base64Image, apiKey: apiKey)
                    Logger.log(.info, "Raw LaTeX from API: \(latex)")
                    
                    let cleanedLatex = cleanLatexString(latex)
                    let copyFormat = settingsManager.extractLatexCopyFormat
                    let textToCopy = copyFormat == "lineBreaks" ? cleanedLatex : cleanedLatex.replacingOccurrences(of: "\n", with: " ")
                    
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    Logger.log(.info, "Copied LaTeX to clipboard (format: \(copyFormat))")
                    showSuccessFeedback()
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
        if let button = self.statusItem.button {
            let originalImage = button.image
            button.image = .with(symbolName: Icons.checkmark, pointSize: 15)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak button] in
                button?.image = originalImage
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
}

// MARK: - Private

private extension App {
    class ResultItem: NSMenuItem { /* Just a sub-class to be identifiable */ }

    func clearMenuItems() {
        extractLatexItem.isHidden = true
        statusItem.menu?.removeItems { $0 is ResultItem }
    }
}

extension App: NSMenuDelegate {
    // No duplicate methods here - they're already defined in the main class
}

enum ExtractionType {
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
