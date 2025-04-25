//
//  App.swift
//  TextGrabber2
//
//  Created by cyan on 2024/3/20.
//

import AppKit
import ServiceManagement
import Foundation
import SwiftUI

@MainActor
final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var currentResult: Recognizer.ResultData?
    private var pasteboardObserver: Timer?
    private var pasteboardChangeCount = 0

    internal let statusItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = .terminationOnRemoval
        item.autosaveName = Bundle.main.bundleName
        item.button?.image = .with(symbolName: Icons.textViewFinder, pointSize: 15)

        let menu = NSMenu()
        // ... rest of menu setup
        menu.delegate = self
        item.menu = menu
        return item
    }()

    private lazy var extractVisionItem: NSMenuItem = {
        let item = NSMenuItem(title: String(localized: "menu.extract.vision"))
        item.addAction { [weak self] in
            self?.triggerVisionExtraction()
        }
        return item
    }()

    private lazy var extractLatexItem: NSMenuItem = {
        let item = NSMenuItem(title: String(localized: "menu.extract.latex"))
        item.addAction { [weak self] in
            self?.triggerLatexExtraction()
        }
        return item
    }()

    private lazy var settingsItem: NSMenuItem = {
        let item = NSMenuItem(title: String(localized: "menu.settings"))
        item.addAction { [weak self] in
            self?.openSettingsWindow()
        }
        return item
    }()

    private lazy var quitItem: NSMenuItem = {
        let item = NSMenuItem(title: String(localized: "menu.quit"),
                            action: nil,
                            keyEquivalent: "q")
        item.keyEquivalentModifierMask = .command
        item.addAction {
            NSApp.terminate(nil)
        }
        return item
    }()

    private let latexService: LatexAPIService
    private let screenCapture = ScreenCapture()

    override init() {
        self.latexService = LatexAPIService()
        super.init()
    }
    
    private var settingsWindowController: SettingsWindowController?
    private let shortcutMonitor = ShortcutMonitor()
    
    private func triggerVisionExtraction() {
        statusItem.menu?.cancelTracking()
        screenCapture.selectRegion { [weak self] (image: CGImage?) in
            guard let self = self, let image = image else { return }
            self.performVisionExtraction(image: image)
        }
    }
    
    private func triggerLatexExtraction() {
        statusItem.menu?.cancelTracking()
        screenCapture.selectRegion { [weak self] (image: CGImage?) in
            guard let self = self, let image = image else { return }
            self.performLatexExtraction(image: image)
        }
    }
    
    private func performVisionExtraction(image: CGImage) {
        Task {
            let result = await Recognizer.detect(image: image, level: .accurate)
            
            guard !result.candidates.isEmpty else {
                NSAlert.runModal(message: String(localized: "alert.no_text"))
                return
            }
            
            // Copy result based on candidates
            NSPasteboard.general.string = result.candidates.first ?? ""
            
            if let button = statusItem.button {
                let originalImage = button.image
                button.image = .with(symbolName: Icons.checkmark, pointSize: 15)
                
                // Revert back after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak button] in
                    button?.image = originalImage
                }
            }
            
            Logger.log(.info, "Vision extraction completed")
        }
    }
    
    private func performLatexExtraction(image: CGImage) {
        Task {
            do {
                guard let apiKey = SettingsManager.shared.getGeminiApiKey(),
                      !apiKey.isEmpty else {
                    NSAlert.runModal(message: String(localized: "alert.api_key_missing"))
                    return
                }
                
                // Convert CGImage to PNG data using NSBitmapImageRep
                let bitmapRep = NSBitmapImageRep(cgImage: image)
                guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "TextGrabber", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to convert image to PNG"
                    ])
                }
                
                let base64String = pngData.base64EncodedString()
                
                // Call Gemini API
                var latex = try await latexService.extractLatex(from: base64String)
                
                // Clean up the LaTeX response
                latex = latex.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove LaTeX markdown delimiters
                let markdownDelimiters = ["$$", "\\[", "\\]"]
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
                
                menu.insertItem(item, at: menu.index(of: self.hintItem) + 1)
                
                if copied {
                    self.hintItem.title = "LaTeX copied! Click to copy again"
                } else {
                    self.hintItem.title = "Failed to copy LaTeX"
                    Logger.log(.error, "Failed to write to clipboard")
                }
                
                Logger.log(.info, "LaTeX extraction completed")
            } catch {
                NSAlert.runModal(message: error.localizedDescription)
                Logger.log(.error, "LaTeX extraction failed: \(error)")
            }
        }
    }
    
    private func openSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        
        settingsWindowController?.showWindow(nil as Any?)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.isVisible = true
    }
}

// MARK: - NSMenuDelegate

extension App: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        startDetection()
        
        servicesItem.submenu?.removeItems { $0 is ServiceItem }
        for service in Services.items.reversed() {
            let item = ServiceItem(title: service.displayName)
            item.addAction {
                NSPasteboard.general.string = self.currentResult?.spacesJoined
                
                if !NSPerformService(service.serviceName, .general) {
                    NSAlert.runModal(message: String(format: Localized.failedToRun, service.displayName))
                }
            }

            servicesItem.submenu?.insertItem(item, at: 0)
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }

            DispatchQueue.main.async {
                guard NSPasteboard.general.changeCount != self.pasteboardChangeCount else {
                    return
                }

                self.startDetection()
            }
        }

        pasteboardObserver = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    func menuDidClose(_ menu: NSMenu) {
        clearMenuItems()

        pasteboardObserver?.invalidate()
        pasteboardObserver = nil
    }
}

// MARK: - Private

private extension App {
    class ResultItem: NSMenuItem { /* Just a sub-class to be identifiable */ }
    class ServiceItem: NSMenuItem { /* Just a sub-class to be identifiable */ }

    func clearMenuItems() {
        hintItem.title = Localized.menuTitleHintCapture
        howToItem.isHidden = false
        copyAllItem.isHidden = true
        statusItem.menu?.removeItems { $0 is ResultItem }
    }

    func startDetection() {
        guard let menu = statusItem.menu else {
            return Logger.assertFail("Missing menu to proceed")
        }

        currentResult = nil
        pasteboardChangeCount = NSPasteboard.general.changeCount
        clipboardItem.isHidden = NSPasteboard.general.isEmpty
        saveImageItem.isEnabled = false

        guard let image = NSPasteboard.general.image?.cgImage else {
            return Logger.log(.info, "No image was copied")
        }

        hintItem.title = Localized.menuTitleHintRecognizing
        howToItem.isHidden = true

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
        hintItem.title = resultData.candidates.isEmpty ? Localized.menuTitleHintCapture : Localized.menuTitleHintCopy
        howToItem.isHidden = !resultData.candidates.isEmpty
        copyAllItem.isHidden = resultData.candidates.count < 2
        saveImageItem.isEnabled = true

        let separator = NSMenuItem.separator()
        menu.insertItem(separator, at: menu.index(of: howToItem) + 1)
        menu.removeItems { $0 is ResultItem }

        for text in resultData.candidates.reversed() {
            let item = ResultItem(title: text)
            item.addAction { NSPasteboard.general.string = text }
            menu.insertItem(item, at: menu.index(of: separator) + 1)
        }
    }
}
