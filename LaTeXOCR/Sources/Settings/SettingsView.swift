import SwiftUI
import Carbon

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

    var body: some View {
        Button {
            if isRecording {
                eventMonitor = nil
                isRecording = false
            } else {
                isRecording = true
                startRecording()
            }
        } label: {
            HStack {
                Text(isRecording ? "Recording..." : (shortcut?.description ?? "Click to Record"))
                    .foregroundStyle(isRecording ? .secondary : .primary)
                if !isRecording {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func startRecording() {
        DispatchQueue.main.async {
            self.eventMonitor = nil
            self.eventMonitor = EventMonitor(eventMask: [.keyDown, .flagsChanged]) { event in
                if event.type == .keyDown &&
                   event.keyCode != kVK_Shift &&
                   event.keyCode != kVK_Control &&
                   event.keyCode != kVK_Option &&
                   event.keyCode != kVK_Command &&
                   event.keyCode != kVK_Function {
                    let newShortcut = ShortcutMonitor.KeyboardShortcut(
                        keyCode: Int(event.keyCode),
                        modifiers: event.modifierFlags
                    )
                    shortcut = newShortcut
                    isRecording = false
                    self.eventMonitor = nil
                    return nil
                } else if event.type == .flagsChanged {
                    return event
                }
                return event
            }
        }
    }
}

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @AppStorage("geminiAPIKey") private var apiKeyInput: String = ""
    @State private var isValidAPIKey: Bool = false

    private func validateAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.starts(with: "AIza") && trimmed.count == 39
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Gemini API Key:") {
                        HStack {
                            SecureField("Enter your API key", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                                .onChange(of: apiKeyInput) { _, newValue in
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if newValue != trimmed {
                                        apiKeyInput = trimmed
                                    }
                                    isValidAPIKey = validateAPIKey(trimmed)
                                }
                            if !apiKeyInput.isEmpty {
                                if isValidAPIKey {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    if !apiKeyInput.isEmpty && !isValidAPIKey {
                        Text("Invalid API key format. Key should start with 'AIza' followed by 35 characters.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Text("Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .tint(.blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Gemini Model:") {
                        Picker("", selection: $settings.selectedModel) {
                            ForEach(Config.availableGeminiModels) { model in
                                Text(model.label).tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 330)
                    }
                    Text("Choose speed / cost trade-offs for AI extraction")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("API Configuration")
            } footer: {
                Text("The API key is required for AI-powered extraction")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Text Shortcut:") {
                    ShortcutRecorderButton(
                        label: "Text Shortcut",
                        shortcut: Binding(
                            get: { settings.textShortcut },
                            set: { settings.textShortcut = $0 }
                        )
                    )
                    .frame(width: 200)
                }

                LabeledContent("Default Prompt:") {
                    ShortcutRecorderButton(
                        label: "Default Prompt Shortcut",
                        shortcut: Binding(
                            get: { settings.defaultPromptShortcut },
                            set: { settings.defaultPromptShortcut = $0 }
                        )
                    )
                    .frame(width: 200)
                }
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("Text uses offline Vision OCR. Default Prompt uses your selected AI prompt.")
                    .foregroundStyle(.secondary)
            }

            Section {
                PromptListView()
                    .frame(height: 280)
            } header: {
                Text("Prompts")
            } footer: {
                Text("Manage AI prompts for extraction. Set a default prompt for the keyboard shortcut.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 700)
        .onAppear {
            isValidAPIKey = validateAPIKey(apiKeyInput)
        }
    }
}

#Preview {
    SettingsView()
}
