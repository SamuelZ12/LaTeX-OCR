import ServiceManagement

extension SMAppService {
  var isEnabled: Bool {
    status == .enabled
  }

  func toggle() throws {
    try (isEnabled ? unregister() : register())
  }
}
