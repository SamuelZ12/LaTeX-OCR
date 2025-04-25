import AppKit

class SettingsViewController: NSViewController {
    private var apiKeyField: NSTextField!
    private var textFormatPopup: NSPopUpButton!
    private var latexFormatPopup: NSPopUpButton!
    
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
        apiKeyField.isEditable = true
        apiKeyField.isSelectable = true
        apiKeyField.usesSingleLineMode = true
        apiKeyField.cell?.wraps = false
        apiKeyField.cell?.isScrollable = true
        
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
        view.addSubview(saveButton)
        
        // Store references
        self.apiKeyField = apiKeyField
        self.textFormatPopup = textFormatPopup
        self.latexFormatPopup = latexFormatPopup
    }
    
    @objc private func saveSettings() {
        UserDefaults.standard.set(apiKeyField.stringValue, forKey: "geminiAPIKey")
        UserDefaults.standard.set(textFormatPopup.selectedItem?.title.lowercased(), forKey: "extractTextCopyFormat")
        UserDefaults.standard.set(latexFormatPopup.selectedItem?.title.lowercased(), forKey: "extractLatexCopyFormat")
        view.window?.close()
    }
}
