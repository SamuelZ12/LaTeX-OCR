import AppKit

extension NSAlert {
  static func runModal(message: String, style: Style = .critical) {
    NSApp.activate()

    let alert = Self()
    alert.alertStyle = style
    alert.messageText = message
    alert.runModal()
  }
}
