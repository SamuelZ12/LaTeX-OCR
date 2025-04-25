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
                
                // Copy LaTeX to pasteboard
                NSPasteboard.general.string = latex
                
                if let button = statusItem.button {
                    let originalImage = button.image
                    button.image = .with(symbolName: Icons.checkmark, pointSize: 15)
                    
                    // Revert back after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak button] in
                        button?.image = originalImage
                    }
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
        setupShortcuts()
    }
    
    private func setupShortcuts() {
        if let visionShortcut = SettingsManager.shared.getShortcut(forType: "visionShortcut") {
            shortcutMonitor.registerShortcut(visionShortcut) { [weak self] in
                self?.triggerVisionExtraction()
            }
        }
        
        if let latexShortcut = SettingsManager.shared.getShortcut(forType: "latexShortcut") {
            shortcutMonitor.registerShortcut(latexShortcut) { [weak self] in
                self?.triggerLatexExtraction()
            }
        }
        
        shortcutMonitor.start()
    }

    // MARK: - NSMenuDelegate
    @objc func menuWillOpen(_ menu: NSMenu) {
        // Menu delegate stays minimal - no automatic detection
    }

    @objc func menuDidClose(_ menu: NSMenu) {
        // Menu delegate stays minimal - no cleanup needed
    }
}
