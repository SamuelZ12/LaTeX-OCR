import Foundation

extension UserDefaults {
    func setCodable<T: Codable>(_ value: T?, forKey key: String) {
        if let value = value,
           let data = try? JSONEncoder().encode(value) {
            set(data, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
    
    func codable<T: Codable>(forKey key: String) -> T? {
        guard let data = data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else {
            return nil
        }
        return value
    }
}