import AppKit

extension NSMenuItem {
  convenience init(title: String) {
    self.init(title: title, action: nil, keyEquivalent: "")
  }

  func setOn(_ on: Bool) {
    state = on ? .on : .off
  }

  func toggle() {
    state = state == .on ? .off : .on
  }
}
