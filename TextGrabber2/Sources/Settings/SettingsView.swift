import SwiftUI

// Add EventMonitor class to manage monitor lifecycle
private class EventMonitor {
    var monitor: Any?
    
    init(eventMask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        self.monitor = NSEvent.addLocalMonitorForEvents(matching: eventMask, handler: handler)
    }
    
    deinit {
        if let monitor = self.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct ShortcutRecorderButton: View {
    let label: String
    @Binding var shortcut: ShortcutMonitor.KeyboardShortcut?
    @State private var isRecording = false
    @State private var eventMonitor: EventMonitor?
    
    init(label: String, shortcut: Binding<ShortcutMonitor.KeyboardShortcut?>) {
        self.label = label
        self._shortcut = shortcut
    }
    
    var body: some View {
        Button(action: {
            if isRecording {
                // Cancel recording
                eventMonitor = nil
                isRecording = false
            } else {
                isRecording = true
                startRecording()
            }
        }) {
            Text(isRecording ? "Recording..." : (shortcut?.description ?? "Click to Record"))
                .frame(width: 150)
        }
        .buttonStyle(.bordered)
    }
    
    private func startRecording() {
        DispatchQueue.main.async {
            self.eventMonitor = EventMonitor(eventMask: [.keyDown, .flagsChanged]) { event in
                if event.type == .keyDown {
                    let newShortcut = ShortcutMonitor.KeyboardShortcut(
                        keyCode: Int(event.keyCode),
                        modifiers: event.modifierFlags
                    )
                    shortcut = newShortcut
                    isRecording = false
                    self.eventMonitor = nil // This will trigger deinit and cleanup
                    return nil
                }
                return event
            }
        }
    }
}

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("API Key") {
                TextField("Gemini API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "geminiAPIKey")
                    }
            }
            
            Section("Keyboard Shortcuts") {
                HStack {
                    Text("Text Shortcut:")
                    Spacer()
                    ShortcutRecorderButton(
                        label: "Text Shortcut",
                        shortcut: Binding(
                            get: { settings.textShortcut },
                            set: { settings.textShortcut = $0 }
                        )
                    )
                }
                
                HStack {
                    Text("LaTeX Shortcut:")
                    Spacer()
                    ShortcutRecorderButton(
                        label: "LaTeX Shortcut",
                        shortcut: Binding(
                            get: { settings.latexShortcut },
                            set: { settings.latexShortcut = $0 }
                        )
                    )
                }
            }
            
            Section("Copy Format") {
                Picker("Text Copy Format:", selection: $settings.extractTextCopyFormat) {
                    Text("Line Breaks").tag("lineBreaks")
                    Text("Spaces").tag("spaces")
                }
                
                Picker("LaTeX Copy Format:", selection: $settings.extractLatexCopyFormat) {
                    Text("Line Breaks").tag("lineBreaks")
                    Text("Spaces").tag("spaces")
                }
            }
            
            HStack {
                Spacer()
                Button("Save") {
                    UserDefaults.standard.set(apiKey, forKey: "geminiAPIKey")
                    settings.objectWillChange.send()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 480, height: 300)
    }
}

#Preview {
    SettingsView()
}
