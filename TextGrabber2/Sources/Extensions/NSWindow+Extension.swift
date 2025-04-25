//
//  NSWindow+Extension.swift
//  TextGrabber2
//
//  Created by cyan on 2024/3/21.
//

import AppKit

extension NSWindow {
  /**
   Hook the setFrame method to have a fixed width.
   */
  static let swizzleSetFrameDisplayAnimateOnce: () = {
    NSWindow.exchangeInstanceMethods(
      originalSelector: #selector(setFrame(_:display:animate:)),
      swizzledSelector: #selector(swizzled_setFrame(_:display:animate:))
    )
  }()

  @objc func swizzled_setFrame(_ originalRect: CGRect, display: Bool, animate: Bool) {
    // Only for the first popup menu window
    guard NSApp.windows.first(where: { $0.className == "NSPopupMenuWindow" }) === self else {
      return swizzled_setFrame(originalRect, display: display, animate: animate)
    }

    // Retrieve the status item and its button frame
    guard let app = NSApp.delegate as? App,
          let button = app.statusItem.button,
          let frame = button.window?.frame,
          let screen = button.window?.screen else {
      return swizzled_setFrame(originalRect, display: display, animate: animate)
    }

    // Ensure the window always appears below the status item, within the screen boundaries
    var preferredRect = originalRect
    preferredRect.size.width = Constants.preferredWidth
    preferredRect.origin.x = min(
      max(frame.minX - Constants.breathPadding, Constants.breathPadding),
      (screen.frame.width) - Constants.preferredWidth - Constants.breathPadding
    )

    swizzled_setFrame(preferredRect, display: display, animate: animate)
  }
}

// MARK: - Private
private extension NSWindow {
  enum Constants {
    static let preferredWidth: Double = 240
    static let breathPadding: Double = 8
  }
}
