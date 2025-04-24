//
//  App.swift
//  TextGrabber2
//
//  Created by cyan on 2024/3/20.
//

import AppKit
import ServiceManagement

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

  // ADD: Configuration for Gemini API
  private let geminiAPIKey = "AIzaSyBoP7ZVuXOOVjZM1JDlDQL9jF-ViKb3dVU"
  private let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

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
    
    // Convert NSImage to PNG data
    guard let tiffData = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
      Logger.log(.error, "Failed to convert image to PNG data")
      return
    }
    
    let base64Image = imageData.base64EncodedString()
    
    // Update menu to show processing state
    hintItem.title = "Processing LaTeX..."
    
    Task {
      do {
        let latex = try await getLatexFromGemini(imageBase64: base64Image)
        
        // Add result to menu
        guard let menu = statusItem.menu else { return }
        
        // Remove any existing LaTeX results
        menu.removeItems { $0 is ResultItem }
        
        let separator = NSMenuItem.separator()
        menu.insertItem(separator, at: menu.index(of: howToItem) + 1)
        
        let item = ResultItem(title: latex)
        item.addAction {
          NSPasteboard.general.string = latex
          Logger.log(.info, "Copied LaTeX to clipboard")
        }
        menu.insertItem(item, at: menu.index(of: separator) + 1)
        
        // Reset hint
        hintItem.title = Localized.menuTitleHintCopy
        
      } catch {
        Logger.log(.error, "LaTeX extraction failed: \(error)")
        hintItem.title = "LaTeX extraction failed"
      }
    }
  }
  
  private func getLatexFromGemini(imageBase64: String) async throws -> String {
    let payload: [String: Any] = [
      "contents": [[
        "parts": [
          ["text": "Convert the mathematical expression in this image to LaTeX code. Return only the LaTeX code without any additional text or explanation."],
          ["inline_data": [
            "mime_type": "image/png",
            "data": imageBase64
          ]]
        ]
      ]]
    ]
    
    guard let url = URL(string: "\(geminiEndpoint)?key=\(geminiAPIKey)") else {
      throw NSError(domain: "TextGrabber", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NSError(domain: "TextGrabber", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    
    if httpResponse.statusCode != 200 {
      if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let error = errorJson["error"] as? [String: Any],
         let message = error["message"] as? String {
        throw NSError(domain: "TextGrabber", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
      } else {
        throw NSError(domain: "TextGrabber", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API request failed with status \(httpResponse.statusCode)"])
      }
    }
    
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let candidates = json["candidates"] as? [[String: Any]],
          let content = candidates.first?["content"] as? [String: Any],
          let parts = content["parts"] as? [[String: Any]],
          let text = parts.first?["text"] as? String else {
      throw NSError(domain: "TextGrabber", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
    }
    
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    // Update the services menu
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

    // For an edge case, we can capture the screen while the menu is shown.
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
      showResult(fastResult, in: menu)

      let accurateResult = await Recognizer.detect(image: image, level: .accurate)
      showResult(accurateResult, in: menu)
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
