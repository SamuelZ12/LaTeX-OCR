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

    private lazy var statusItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = .terminationOnRemoval
        item.autosaveName = Bundle.main.bundleName
        item.button?.image = .with(symbolName: Icons.textViewFinder, pointSize: 15)

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(hintItem)
        menu.addItem(howToItem)
        menu.addItem(.separator())
        menu.addItem(copyAllItem)
        menu.addItem(extractLatexItem)
        menu.addItem(servicesItem)
        menu.addItem(clipboardItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)

        menu.addItem(withTitle: Localized.menuTitleGitHub) {
            NSWorkspace.shared.safelyOpenURL(string: Links.github)
        }

        menu.addItem(.separator())
        menu.addItem({
            let item = NSMenuItem(title: "\(Localized.menuTitleVersion) \(Bundle.main.shortVersionString)")
            item.isEnabled = false

            return item
        }())

        menu.addItem({
            let item = NSMenuItem(title: Localized.menuTitleQuitTextGrabber2, action: nil, keyEquivalent: "q")
            item.keyEquivalentModifierMask = .command
            item.addAction {
                NSApp.terminate(nil)
            }

            return item
        }())

        item.menu = menu
        return item
    }()

    private let hintItem = NSMenuItem()
    private let howToItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleHowTo)
        item.addAction {
            NSWorkspace.shared.safelyOpenURL(string: "\(Links.github)/wiki#capture-screen-on-mac")
        }

        return item
    }()

    private lazy var copyAllItem: NSMenuItem = {
        let menu = NSMenu()
        menu.addItem(withTitle: Localized.menuTitleJoinDirectly) {
            NSPasteboard.general.string = self.currentResult?.directlyJoined
        }

        menu.addItem(withTitle: Localized.menuTitleJoinWithLineBreaks) {
            NSPasteboard.general.string = self.currentResult?.lineBreaksJoined
        }

        menu.addItem(withTitle: Localized.menuTitleJoinWithSpaces) {
            NSPasteboard.general.string = self.currentResult?.spacesJoined
        }

        let item = NSMenuItem(title: Localized.menuTitleCopyAll)
        item.submenu = menu
        return item
    }()

    private lazy var extractLatexItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleExtractLaTeX)
        item.addAction { [weak self] in
            self?.extractLatex()
        }
        return item
    }()

    private lazy var servicesItem: NSMenuItem = {
        let menu = NSMenu()
        menu.addItem(.separator())

        menu.addItem(withTitle: Localized.menuTitleConfigure) {
            NSWorkspace.shared.open(Services.fileURL)
        }

        menu.addItem(withTitle: Localized.menuTitleDocumentation) {
            NSWorkspace.shared.safelyOpenURL(string: "\(Links.github)/wiki#connect-to-system-services")
        }

        let item = NSMenuItem(title: Localized.menuTitleServices)
        item.submenu = menu
        return item
    }()

    private lazy var clipboardItem: NSMenuItem = {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(saveImageItem)

        menu.addItem(withTitle: Localized.menuTitleClearContents) {
            NSPasteboard.general.clearContents()
        }

        let item = NSMenuItem(title: Localized.menuTitleClipboard)
        item.submenu = menu
        return item
    }()

    private let saveImageItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleSaveAsFile)
        item.addAction {
            NSPasteboard.general.saveImageAsFile()
        }

        return item
    }()

    private let launchAtLoginItem: NSMenuItem = {
        let item = NSMenuItem(title: Localized.menuTitleLaunchAtLogin)
        item.addAction { [weak item] in
            do {
                try SMAppService.mainApp.toggle()
            } catch {
                Logger.log(.error, "\(error)")
            }

            item?.toggle()
        }

        item.setOn(SMAppService.mainApp.isEnabled)
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
            hintItem.title = "No image in clipboard"
            return
        }
        
        Logger.log(.info, "API key is configured")
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
            Logger.log(.error, "Failed to convert image to PNG data")
            hintItem.title = "Failed to convert image"
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        Logger.log(.info, "Image converted to base64")
        
        hintItem.title = "Processing LaTeX..."
        
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
                
                menu.insertItem(item, at: menu.index(of: self.hintItem) + 1)
                
                if copied {
                    self.hintItem.title = "LaTeX copied! Click to copy again"
                } else {
                    self.hintItem.title = "Failed to copy LaTeX"
                    Logger.log(.error, "Failed to write to clipboard")
                }
                
            } catch {
                let errorMessage = "LaTeX extraction failed: \(error.localizedDescription)"
                Logger.log(.error, errorMessage)
                self.hintItem.title = errorMessage
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
