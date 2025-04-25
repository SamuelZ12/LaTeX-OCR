//
//  App.swift
//  TextGrabber2
//
//  Created by cyan on 2024/3/20.
//

import AppKit
import ServiceManagement
import Foundation

@MainActor
final class App: NSObject, NSApplicationDelegate {
    private var currentResult: Recognizer.ResultData?
    private var pasteboardObserver: Timer?
    private var pasteboardChangeCount = 0
    private var settingsWindowController: SettingsWindowController?

    private lazy var extractTextItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleExtractText)
        item.addAction { [weak self] in
            self?.performExtraction(type: .text)
        }
        return item
    }()

    private lazy var extractLatexItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleExtractLaTeX)
        item.addAction { [weak self] in
            self?.performExtraction(type: .latex)
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
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Services.initialize()
        clearMenuItems()
        statusItem.isVisible = true
    }
}

// MARK: - NSMenuDelegate

extension App: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        extractLatexItem.isHidden = true
        extractTextItem.isHidden = true  // Hide both items initially
        
        if NSPasteboard.general.image?.cgImage != nil {
            extractLatexItem.isHidden = false
            extractTextItem.isHidden = false  // Show both items if image exists
        }
        
        // Start detection and check for image
        startDetection()
    }

    func menuDidClose(_ menu: NSMenu) {
        clearMenuItems()
    }
}

// MARK: - Private

private extension App {
    class ResultItem: NSMenuItem { /* Just a sub-class to be identifiable */ }

    func clearMenuItems() {
        extractLatexItem.isHidden = true
        statusItem.menu?.removeItems { $0 is ResultItem }
    }

    func startDetection() {
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

    func performExtraction(type: ExtractionType) {
        guard let image = NSPasteboard.general.image else {
            NSAlert.showModalAlert(message: "Please capture a screen region first (Control-Shift-Command-4)")
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
                let copyFormat = UserDefaults.standard.string(forKey: "extractTextCopyFormat") ?? "lineBreaks"
                let textToCopy = copyFormat == "lineBreaks" ? result.lineBreaksJoined : result.spacesJoined
                
                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                let copied = pasteboard.setString(textToCopy, forType: .string)
                
                if copied {
                    // Show visual feedback
                    if let button = self.statusItem.button {
                        let originalImage = button.image
                        button.image = .with(symbolName: Icons.checkmark, pointSize: 15)
                        
                        // Revert back to original icon after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak button] in
                            button?.image = originalImage
                        }
                    }
                    
                    // Add result to menu for later copying
                    guard let menu = statusItem.menu else { return }
                    showResult(result, in: menu)
                }
            }
            
        case .latex:
            guard let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey"), !apiKey.isEmpty else {
                NSAlert.showModalAlert(message: "Please set your Gemini API key in Settings")
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
                    var latex = try await latexService.extractLatex(from: base64Image)
                    Logger.log(.info, "Raw LaTeX from API: \(latex)")
                    
                    // Clean up the response (basic cleaning)
                    latex = latex.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Optional: Add more aggressive cleaning if needed, like removing markdown
                    // latex = latex.replacingOccurrences(of: "```latex", with: "").replacingOccurrences(of: "```", with: "")
                    // latex = latex.trimmingCharacters(in: .whitespacesAndNewlines)

                    let copyFormat = UserDefaults.standard.string(forKey: "extractLatexCopyFormat") ?? "lineBreaks"
                    let textToCopy = copyFormat == "lineBreaks" ? latex : latex.replacingOccurrences(of: "\n", with: " ")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    Logger.log(.info, "Copied LaTeX to clipboard (format: \(copyFormat))")
                    showSuccessFeedback()
                } catch let error as LatexAPIError {
                    switch error {
                    case .apiError(let message) where message.contains("API key not valid"): // More specific check if possible
                        NSAlert.showModalAlert(message: "Invalid Gemini API key. Please check Settings.")
                    case .apiError(let message):
                        NSAlert.showModalAlert(message: "Gemini API Error: \(message)")
                    default:
                        NSAlert.showModalAlert(message: "Failed to extract LaTeX: \(error.localizedDescription)")
                    }
                    Logger.log(.error, "LaTeX extraction failed: \(error)")
                } catch {
                    NSAlert.showModalAlert(message: "Failed to extract LaTeX: \(error.localizedDescription)")
                    Logger.log(.error, "LaTeX extraction failed: \(error)")
                }
            }
        }
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
