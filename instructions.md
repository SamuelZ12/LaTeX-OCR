1. Modify the Menu Structure in App.swift
Objective: Simplify the menu bar to include only "Extract Text (Apple Vision)", "Extract LaTeX (Gemini)", "Settings", and "Quit".
Steps:
Open TextGrabber2/Sources/App.swift.
Locate the statusItem lazy property where the NSMenu is defined.
Replace the existing menu setup with the following structure:
Extract Text (Apple Vision): A menu item to trigger text extraction.
Extract LaTeX (Gemini): A menu item to trigger LaTeX extraction.
Settings: A menu item to open a settings window.
Quit: A menu item to exit the app.
Remove unnecessary items like howToItem, copyAllItem, servicesItem, clipboardItem, launchAtLoginItem, and the GitHub/version items to streamline the interface.
Example structure:
swift

Copy
private lazy var statusItem: NSStatusItem = {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.image = .with(symbolName: Icons.textViewFinder, pointSize: 15)
    
    let menu = NSMenu()
    menu.delegate = self
    
    menu.addItem(extractTextItem)
    menu.addItem(extractLatexItem)
    menu.addItem(settingsItem)
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    
    item.menu = menu
    return item
}()

private lazy var extractTextItem: NSMenuItem = {
    let item = NSMenuItem(title: "Extract Text (Apple Vision)")
    item.addAction { [weak self] in self?.performExtractText() }
    return item
}()

private lazy var extractLatexItem: NSMenuItem = {
    let item = NSMenuItem(title: "Extract LaTeX (Gemini)")
    item.addAction { [weak self] in self?.performExtractLatex() }
    return item
}()

private lazy var settingsItem: NSMenuItem = {
    let item = NSMenuItem(title: "Settings")
    item.addAction { [weak self] in self?.openSettings() }
    return item
}()
Ensure the NSMenuDelegate methods (menuWillOpen and menuDidClose) are updated to remove references to deleted items and focus only on enabling/disabling extraction items based on clipboard content.
2. Implement Region Selection Workflow
Objective: Allow users to select a screen region after clicking a submenu, using the system’s screen capture tool to avoid permissions.
Approach: Since TextGrabber2 avoids screen recording permissions, rely on the user capturing a region to the clipboard first (e.g., via Control-Shift-Command-4), then process it after menu selection. Inform the user of this workflow.
Steps:
User Instruction: Update README.md to clarify that users must capture a screen region to the clipboard before selecting "Extract Text" or "Extract LaTeX". Example:
text

Copy
To extract text or LaTeX:
1. Press Control-Shift-Command-4 to capture a screen region (copied to clipboard).
2. Click the TextGrabber2 menu bar icon and select "Extract Text (Apple Vision)" or "Extract LaTeX (Gemini)".
Code Adjustment: In performExtractText() and performExtractLatex(), check for a clipboard image and process it directly, assuming the user has already captured the region.
Feedback: If no image is present, display an alert (e.g., "Please capture a screen region first").
3. Implement Text Extraction with Apple Vision
Objective: Process the clipboard image using the Vision framework when "Extract Text" is selected.
Steps:
In App.swift, add a new function performExtractText():
swift

Copy
func performExtractText() {
    guard let image = NSPasteboard.general.image?.cgImage else {
        NSAlert.runModal(message: "Please capture a screen region first")
        return
    }
    
    Task {
        let result = await Recognizer.detect(image: image, level: .accurate)
        let copyFormat = UserDefaults.standard.string(forKey: "extractTextCopyFormat") ?? "lineBreaks"
        let textToCopy = copyFormat == "lineBreaks" ? result.lineBreaksJoined : result.spacesJoined
        NSPasteboard.general.string = textToCopy
    }
}
Reuse the existing Recognizer.detect function from Recognizer.swift to perform text recognition.
Apply the user’s copy format preference (set in settings) to join the text with line breaks or spaces.
4. Implement LaTeX Extraction with Gemini
Objective: Process the clipboard image using the Gemini API for LaTeX extraction when "Extract LaTeX" is selected.
Steps:
In App.swift, modify or add a performExtractLatex() function:
swift

Copy
func performExtractLatex() {
    guard let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey"), !apiKey.isEmpty else {
        NSAlert.runModal(message: "Please set your Gemini API key in Settings")
        return
    }
    
    guard let image = NSPasteboard.general.image, let imageData = image.pngData else {
        NSAlert.runModal(message: "Please capture a screen region first")
        return
    }
    
    let base64Image = imageData.base64EncodedString()
    
    Task {
        do {
            let latex = try await latexService.extractLatex(from: base64Image)
            let copyFormat = UserDefaults.standard.string(forKey: "extractLatexCopyFormat") ?? "lineBreaks"
            let textToCopy = copyFormat == "lineBreaks" ? latex : latex.replacingOccurrences(of: "\n", with: " ")
            NSPasteboard.general.string = textToCopy
        } catch {
            NSAlert.runModal(message: "Failed to extract LaTeX: \(error.localizedDescription)")
        }
    }
}
Use the existing LatexAPIService from LatexAPIService.swift to handle the API call, ensuring it uses the user-provided API key from UserDefaults.
Convert the image to base64 and send it to the Gemini API endpoint (e.g., https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent).
Apply the user’s copy format preference to the returned LaTeX string.
5. Create a Settings Window
Objective: Provide a settings interface for entering the Gemini API key, setting keyboard shortcuts, and choosing copy formats.
Steps:
Add New Files:
Create SettingsWindowController.swift in TextGrabber2/Sources:
swift

Copy
import AppKit

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), 
                             styleMask: [.titled, .closable], 
                             backing: .buffered, 
                             defer: false)
        window.center()
        window.title = "Settings"
        self.init(window: window)
        window.contentViewController = SettingsViewController()
    }
}
Create SettingsViewController.swift in TextGrabber2/Sources:
swift

Copy
import AppKit

class SettingsViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // API Key Text Field
        let apiKeyLabel = NSTextField(labelWithString: "Gemini API Key:")
        apiKeyLabel.frame = NSRect(x: 20, y: 260, width: 100, height: 20)
        let apiKeyField = NSTextField(frame: NSRect(x: 130, y: 260, width: 250, height: 20))
        apiKeyField.stringValue = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        
        // Copy Format Popups
        let textFormatLabel = NSTextField(labelWithString: "Text Copy Format:")
        textFormatLabel.frame = NSRect(x: 20, y: 220, width: 100, height: 20)
        let textFormatPopup = NSPopUpButton(frame: NSRect(x: 130, y: 220, width: 150, height: 20))
        textFormatPopup.addItems(withTitles: ["Line Breaks", "Spaces"])
        textFormatPopup.selectItem(withTitle: UserDefaults.standard.string(forKey: "extractTextCopyFormat")?.capitalized ?? "Line Breaks")
        
        let latexFormatLabel = NSTextField(labelWithString: "LaTeX Copy Format:")
        latexFormatLabel.frame = NSRect(x: 20, y: 180, width: 100, height: 20)
        let latexFormatPopup = NSPopUpButton(frame: NSRect(x: 130, y: 180, width: 150, height: 20))
        latexFormatPopup.addItems(withTitles: ["Line Breaks", "Spaces"])
        latexFormatPopup.selectItem(withTitle: UserDefaults.standard.string(forKey: "extractLatexCopyFormat")?.capitalized ?? "Line Breaks")
        
        // Shortcut Popups (Predefined Options)
        let textShortcutLabel = NSTextField(labelWithString: "Text Shortcut:")
        textShortcutLabel.frame = NSRect(x: 20, y: 140, width: 100, height: 20)
        let textShortcutPopup = NSPopUpButton(frame: NSRect(x: 130, y: 140, width: 150, height: 20))
        textShortcutPopup.addItems(withTitles: ["Command+Shift+T", "Command+Shift+E"])
        textShortcutPopup.selectItem(withTitle: UserDefaults.standard.string(forKey: "extractTextShortcut") ?? "Command+Shift+T")
        
        let latexShortcutLabel = NSTextField(labelWithString: "LaTeX Shortcut:")
        latexShortcutLabel.frame = NSRect(x: 20, y: 100, width: 100, height: 20)
        let latexShortcutPopup = NSPopUpButton(frame: NSRect(x: 130, y: 100, width: 150, height: 20))
        latexShortcutPopup.addItems(withTitles: ["Command+Shift+L", "Command+Shift+M"])
        latexShortcutPopup.selectItem(withTitle: UserDefaults.standard.string(forKey: "extractLatexShortcut") ?? "Command+Shift+L")
        
        // Save Button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: 300, y: 20, width: 80, height: 30)
        
        // Add to view
        view.addSubview(apiKeyLabel)
        view.addSubview(apiKeyField)
        view.addSubview(textFormatLabel)
        view.addSubview(textFormatPopup)
        view.addSubview(latexFormatLabel)
        view.addSubview(latexFormatPopup)
        view.addSubview(textShortcutLabel)
        view.addSubview(textShortcutPopup)
        view.addSubview(latexShortcutLabel)
        view.addSubview(latexShortcutPopup)
        view.addSubview(saveButton)
        
        // Store references for saving
        self.apiKeyField = apiKeyField
        self.textFormatPopup = textFormatPopup
        self.latexFormatPopup = latexFormatPopup
        self.textShortcutPopup = textShortcutPopup
        self.latexShortcutPopup = latexShortcutPopup
    }
    
    private var apiKeyField: NSTextField!
    private var textFormatPopup: NSPopUpButton!
    private var latexFormatPopup: NSPopUpButton!
    private var textShortcutPopup: NSPopUpButton!
    private var latexShortcutPopup: NSPopUpButton!
    
    @objc func saveSettings() {
        UserDefaults.standard.set(apiKeyField.stringValue, forKey: "geminiAPIKey")
        UserDefaults.standard.set(textFormatPopup.selectedItem?.title.lowercased(), forKey: "extractTextCopyFormat")
        UserDefaults.standard.set(latexFormatPopup.selectedItem?.title.lowercased(), forKey: "extractLatexCopyFormat")
        UserDefaults.standard.set(textShortcutPopup.selectedItem?.title, forKey: "extractTextShortcut")
        UserDefaults.standard.set(latexShortcutPopup.selectedItem?.title, forKey: "extractLatexShortcut")
        view.window?.close()
    }
}
Open Settings:
In App.swift, add a property to hold the settings window controller and a method to open it:
swift

Copy
private var settingsWindowController: SettingsWindowController?

func openSettings() {
    if settingsWindowController == nil {
        settingsWindowController = SettingsWindowController()
    }
    settingsWindowController?.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
}
Settings Content:
Gemini API Key: A text field to input the key, saved to UserDefaults with key "geminiAPIKey".
Copy Formats: Two popup buttons (one for text, one for LaTeX) with options "Line Breaks" and "Spaces", saved as "extractTextCopyFormat" and "extractLatexCopyFormat".
Keyboard Shortcuts: Two popup buttons with predefined options (e.g., "Command+Shift+T", "Command+Shift+L"), saved as "extractTextShortcut" and "extractLatexShortcut".
6. Register Global Keyboard Shortcuts
Objective: Allow extraction methods to be triggered via user-defined shortcuts.
Steps:
In App.swift, add properties to store shortcuts and register them:
swift

Copy
private var textShortcut: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)?
private var latexShortcut: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)?

func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem.isVisible = true
    registerHotkeys()
}

private func registerHotkeys() {
    let shortcutMap: [String: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)] = [
        "Command+Shift+T": (17, [.command, .shift]), // T
        "Command+Shift+E": (14, [.command, .shift]), // E
        "Command+Shift+L": (37, [.command, .shift]), // L
        "Command+Shift+M": (46, [.command, .shift])  // M
    ]
    
    textShortcut = shortcutMap[UserDefaults.standard.string(forKey: "extractTextShortcut") ?? "Command+Shift+T"]
    latexShortcut = shortcutMap[UserDefaults.standard.string(forKey: "extractLatexShortcut") ?? "Command+Shift+L"]
    
    NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self = self else { return }
        if let text = self.textShortcut, event.keyCode == text.keyCode && event.modifierFlags.intersection([.command, .shift]) == text.modifiers {
            self.performExtractText()
        } else if let latex = self.latexShortcut, event.keyCode == latex.keyCode && event.modifierFlags.intersection([.command, .shift]) == latex.modifiers {
            self.performExtractLatex()
        }
    }
}
Call registerHotkeys() in openSettings() after saving to update shortcuts dynamically.
7. Ensure Network Access for Gemini API
Objective: Verify the app can make network requests for LaTeX extraction.
Steps:
Check TextGrabber2/Info.entitlements:
xml

Copy
<key>com.apple.security.network.client</key>
<true/>
This is already present, so no changes are needed unless removed previously.
8. Update Project Configuration
Objective: Ensure the new files are included in the build.
**Steps:
Open TextGrabber2.xcodeproj in Xcode.
Add SettingsWindowController.swift and SettingsViewController.swift to the Sources group under TextGrabber2.
Verify they are included in the target’s build phases (TextGrabber2 > Build Phases > Compile Sources).
9. Test and Refine
Objective: Ensure all features work as expected.
Steps:
Build and run the app in Xcode.
Test capturing a screen region, selecting each extraction method, and verifying clipboard output.
Test settings: enter a Gemini API key (obtain from Google Cloud Console), change shortcuts and copy formats, and confirm they apply correctly.
Adjust UI spacing or error messages as needed for clarity.
