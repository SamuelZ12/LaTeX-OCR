import AppKit

public class ShortcutMonitor {
    private var eventMonitor: Any?
    private var shortcuts: [String: () -> Void] = [:]
    private var keycodeConverter = KeycodeConverter()
    
    deinit {
        stop()
    }
    
    func start() {
        stop()
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }
    
    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func registerShortcut(_ shortcutString: String, action: @escaping () -> Void) {
        shortcuts[shortcutString] = action
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let pressedShortcut = keycodeConverter.stringFromEvent(event)
        
        if let action = shortcuts[pressedShortcut] {
            DispatchQueue.main.async {
                action()
            }
        }
    }
}

// MARK: - Keycode Converter
private class KeycodeConverter {
    func stringFromEvent(_ event: NSEvent) -> String {
        var components: [String] = []
        
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if flags.contains(.command) { components.append("⌘") }
        if flags.contains(.option) { components.append("⌥") }
        if flags.contains(.control) { components.append("⌃") }
        if flags.contains(.shift) { components.append("⇧") }
        
        if let key = KeyboardKey(rawValue: Int(event.keyCode)) {
            components.append(key.character)
        }
        
        return components.joined(separator: "")
    }
    
    func parseShortcutString(_ shortcut: String) -> (keyCode: UInt16, flags: NSEvent.ModifierFlags)? {
        // Convert readable shortcut string to keycode and flags
        var flags: NSEvent.ModifierFlags = []
        var keyCharacter = ""
        
        let components = shortcut.components(separatedBy: "")
        
        for component in components {
            switch component {
            case "⌘": flags.insert(.command)
            case "⌥": flags.insert(.option)
            case "⌃": flags.insert(.control)
            case "⇧": flags.insert(.shift)
            default: keyCharacter = component
            }
        }
        
        guard let key = KeyboardKey.allCases.first(where: { $0.character == keyCharacter }) else {
            return nil
        }
        
        return (UInt16(key.rawValue), flags)
    }
}

// MARK: - Keyboard Keys
private enum KeyboardKey: Int, CaseIterable {
    case a = 0
    case s = 1
    case d = 2
    // Add more cases as needed
    
    var character: String {
        switch self {
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        }
    }
}
