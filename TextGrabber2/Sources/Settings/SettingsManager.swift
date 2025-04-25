import Foundation
import Security

@MainActor
public final class SettingsManager: @unchecked Sendable {
    public static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    private let keychain = KeychainAccess()
    
    public enum JoinMethod: String, CaseIterable {
        case lineBreaks = "Line Breaks"
        case spaces = "Spaces"
    }
    
    private enum Keys {
        static let visionJoinMethod = "visionJoinMethod"
        static let latexJoinMethod = "latexJoinMethod"
        static let visionShortcut = "visionShortcut"
        static let latexShortcut = "latexShortcut"
    }
    
    // Make singleton private to force usage of shared
    private init() {}
    
    // MARK: - Join Methods
    public var visionJoinMethod: JoinMethod {
        get {
            if let stored = defaults.string(forKey: Keys.visionJoinMethod),
               let method = JoinMethod(rawValue: stored) {
                return method
            }
            return .lineBreaks
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.visionJoinMethod)
        }
    }
    
    public var latexJoinMethod: JoinMethod {
        get {
            if let stored = defaults.string(forKey: Keys.latexJoinMethod),
               let method = JoinMethod(rawValue: stored) {
                return method
            }
            return .lineBreaks
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.latexJoinMethod)
        }
    }
    
    // MARK: - API Key
    public func getGeminiApiKey() -> String? {
        return keychain.get("geminiApiKey")
    }
    
    public func setGeminiApiKey(_ key: String) {
        keychain.set(key, for: "geminiApiKey")
    }
    
    // MARK: - Shortcuts
    public func setShortcut(_ shortcut: String, forType type: String) {
        defaults.set(shortcut, forKey: type)
    }
    
    public func getShortcut(forType type: String) -> String? {
        return defaults.string(forKey: type)
    }
}

// MARK: - Keychain Helper
private final class KeychainAccess: @unchecked Sendable {
    func set(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
}
