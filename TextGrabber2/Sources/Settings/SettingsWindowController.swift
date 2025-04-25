import AppKit
import Security

class SettingsWindowController: NSWindowController {
    private let apiKeyField = NSTextField()
    private let textFormatPopup = NSPopUpButton()
    private let latexFormatPopup = NSPopUpButton()
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        setupUI()
        loadSettings()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }
        
        // Add notification observer to handle window close properly
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 15
        stackView.alignment = .leading
        stackView.distribution = .fill
        
        apiKeyField.placeholderString = "Enter your Gemini API key"
        apiKeyField.isEditable = true
        apiKeyField.isSelectable = true
        apiKeyField.usesSingleLineMode = true
        apiKeyField.cell?.wraps = false
        apiKeyField.cell?.isScrollable = true
        let apiKeyRow = createRow(label: "Gemini API Key:", field: apiKeyField)
        
        // Configure popups with fixed width to prevent alignment issues
        textFormatPopup.addItems(withTitles: ["Line Breaks", "Spaces"])
        textFormatPopup.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        textFormatPopup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let textFormatRow = createRow(label: "Text Copy Format:", field: textFormatPopup)
        
        latexFormatPopup.addItems(withTitles: ["Line Breaks", "Spaces"])
        latexFormatPopup.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        latexFormatPopup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let latexFormatRow = createRow(label: "LaTeX Copy Format:", field: latexFormatPopup)
        
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        
        let buttonContainer = NSView()
        buttonContainer.addSubview(saveButton)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            saveButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            saveButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor)
        ])

        stackView.addArrangedSubview(apiKeyRow)
        stackView.addArrangedSubview(textFormatRow)
        stackView.addArrangedSubview(latexFormatRow)
        stackView.addArrangedSubview(NSView())
        stackView.addArrangedSubview(buttonContainer)
        
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            apiKeyRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            textFormatRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            latexFormatRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            buttonContainer.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }
    
    private func createRow(label text: String, field: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.distribution = .fill
        row.alignment = .centerY // Changed to centerY for better vertical alignment

        let label = NSTextField(labelWithString: text)
        label.setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 120).isActive = true

        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        row.addArrangedSubview(label)
        row.addArrangedSubview(field)
        
        return row
    }
    
    private func loadSettings() {
        apiKeyField.stringValue = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        
        let textFormat = UserDefaults.standard.string(forKey: "extractTextCopyFormat") ?? "lineBreaks"
        let latexFormat = UserDefaults.standard.string(forKey: "extractLatexCopyFormat") ?? "lineBreaks"
        
        textFormatPopup.selectItem(withTitle: textFormat == "lineBreaks" ? "Line Breaks" : "Spaces")
        latexFormatPopup.selectItem(withTitle: latexFormat == "lineBreaks" ? "Line Breaks" : "Spaces")
    }
    
    @objc private func saveSettings() {
        UserDefaults.standard.set(apiKeyField.stringValue, forKey: "geminiAPIKey")
        
        let textFormat = textFormatPopup.selectedItem?.title == "Line Breaks" ? "lineBreaks" : "spaces"
        let latexFormat = latexFormatPopup.selectedItem?.title == "Line Breaks" ? "lineBreaks" : "spaces"
        
        UserDefaults.standard.set(textFormat, forKey: "extractTextCopyFormat")
        UserDefaults.standard.set(latexFormat, forKey: "extractLatexCopyFormat")
        
        close()
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        // Clean up any resources when window closes
    }
    
    override func showWindow(_ sender: Any?) {
        // Create a fresh window if needed to avoid ViewBridge issues
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
            setupUI()
            loadSettings()
        }
        
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
