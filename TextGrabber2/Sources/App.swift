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
            self?.openSettings()
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

    func extractLatex() {
        guard let image = NSPasteboard.general.image else {
            Logger.log(.error, "No image in clipboard")
            return
        }
        
        Logger.log(.info, "API key is configured")
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
            Logger.log(.error, "Failed to convert image to PNG data")
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        Logger.log(.info, "Image converted to base64")
        
        Task {
            do {
                Logger.log(.info, "Starting Gemini API call")
                var latex = try await self.latexService.extractLatex(from: base64Image)
                Logger.log(.info, "Received LaTeX from API: \(latex)")
                
                // Clean up the response
                latex = latex.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove LaTeX markdown delimiters
                let markdownDelimiters = ["```latex", "```", "$$", "$", "\\begin{align}", "\\end{align}", "\\begin{equation}", "\\end{equation}"]
                for delimiter in markdownDelimiters {
                    latex = latex.replacingOccurrences(of: delimiter, with: "")
                }
                latex = latex.trimmingCharacters(in: .whitespacesAndNewlines)
                
                Logger.log(.info, "Cleaned LaTeX: \(latex)")
                
                // Copy to clipboard using a more reliable method
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                let copied = pasteboard.writeObjects([latex as NSString])
                Logger.log(.info, "Clipboard write successful: \(copied)")
                
                guard let menu = self.statusItem.menu else {
                    Logger.log(.error, "Menu not available")
                    return
                }
                
                menu.removeItems { $0 is ResultItem }
                
                let item = ResultItem(title: latex)
                item.addAction { [latex] in
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    let copied = pasteboard.writeObjects([latex as NSString])
                    Logger.log(.info, "Menu item clipboard copy: \(copied)")
                }
                
                menu.insertItem(item, at: 0)
                
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
                } else {
                    Logger.log(.error, "Failed to write to clipboard")
                }
                
            } catch {
                let errorMessage = "LaTeX extraction failed: \(error.localizedDescription)"
                Logger.log(.error, errorMessage)
            }
        }
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
        extractLatexItem.isHidden = true  // Hide initially when menu opens
        
        // Start detection and check for image
        startDetection()
        
        if let image = NSPasteboard.general.image?.cgImage {
            extractLatexItem.isHidden = false  // Show button if image exists
        }
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
            Logger.log(.error, "No image in clipboard")
            return
        }
        
        switch type {
        case .text:
            // Perform text extraction
            break
        case .latex:
            extractLatex()
        }
    }

    func openSettings() {
        // Open settings
    }
}

enum ExtractionType {
    case text
    case latex
}
