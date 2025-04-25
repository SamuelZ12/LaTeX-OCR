Goal: Simplify the menu, add region selection triggered by menu items, introduce a settings panel for API keys, keyboard shortcuts, and join preferences.

Analysis of Current State:

The app currently reacts to images already on the clipboard (NSPasteboard.general.image).
Detection (Vision OCR) starts automatically when the menu opens (menuWillOpen).
LaTeX extraction is a separate menu item triggered manually, also using the clipboard image.
Settings are minimal ("Launch at Login").
No built-in region selection exists; it relies on external screen capture methods (like macOS shortcuts).
API Key for Gemini seems handled internally (via Config.swift/Secrets.plist), not user-configurable.
Redesign Steps:

Phase 1: Menu and Basic Structure Refactoring

Modify App.swift - Status Bar Menu Setup:

Remove Automatic Detection: In menuWillOpen(_:), remove the call to startDetection() and the logic that depends on automatic clipboard checking (including the pasteboardObserver timer and pasteboardChangeCount). The app should now only act when a user explicitly clicks a menu item.
Remove Old Menu Items: Remove the creation and addition of the following items from the statusItem's menu setup:
hintItem
howToItem
copyAllItem (and its submenu)
servicesItem (and its submenu)
clipboardItem (and its submenu, including saveImageItem)
The existing extractLatexItem (we'll add a new one).
Add New Menu Items: Define and add the following NSMenuItems to the menu structure:
extractVisionItem: Title "Extract Text (Vision)". Action: triggerVisionExtraction (new function to be created).
extractLatexItem: Title "Extract LaTeX (Gemini)". Action: triggerLatexExtraction (new function to be created).
settingsItem: Title "Settings...". Action: openSettingsWindow (new function to be created).
quitItem: Keep the existing "Quit TextGrabber2" item.
Adjust Separators: Add NSMenuItem.separator() between logical groups (e.g., between extraction items and settings/quit).
Modify App.swift - Remove Unused Logic:

Remove the currentResult property, as results will be handled immediately after extraction.
Remove the showResult function, as results won't populate the menu dynamically anymore.
Remove the clearMenuItems function.
Remove the ResultItem and ServiceItem private classes.
Phase 2: Implement Region Selection

Create ScreenCaptureManager.swift (New File):

This class will handle the interactive region selection.
Implement a method like selectRegion(completion: @escaping (CGImage?) -> Void).
Inside selectRegion:
Temporarily hide the main app's status item menu if it's open.
Create a transparent, borderless, full-screen NSWindow.
Set its level to be above normal windows (.screenSaver).
Create a custom NSView for this window to handle mouse events (mouseDown, mouseDragged, mouseUp).
On mouseDown, record the starting point.
On mouseDragged, calculate the rectangle from the start point to the current point and draw a visual indicator (e.g., a semi-transparent overlay with a border) on the custom view.
On mouseUp, record the final rectangle.
Close the transparent window.
Capture the screen content within the final rectangle using CGDisplayCreateImageForRect(CGMainDisplayID(), finalRect).
Call the completion handler with the resulting CGImage (or nil if cancelled/failed).
Note: This requires careful handling of screen coordinates, multi-monitor setups, and user cancellation (e.g., pressing ESC).
Integrate Region Selection into App.swift:

Create the placeholder action functions: triggerVisionExtraction() and triggerLatexExtraction().
Inside triggerVisionExtraction():
Instantiate ScreenCaptureManager.
Call screenCaptureManager.selectRegion { [weak self] image in ... }.
In the completion handler, if image is not nil, call a new function performVisionExtraction(image: image).
Inside triggerLatexExtraction():
Instantiate ScreenCaptureManager.
Call screenCaptureManager.selectRegion { [weak self] image in ... }.
In the completion handler, if image is not nil, call a new function performGeminiExtraction(image: image).
Phase 3: Adapt Extraction Logic

Refactor Vision Extraction (App.swift & Recognizer.swift):

Create the new function performVisionExtraction(image: CGImage).
Move the core Vision recognition logic here. Call Recognizer.detect(image: image, level: .accurate) (or offer choice via settings later).
Result Handling:
Get the ResultData from Recognizer.detect.
Fetch the user's preferred join method for Vision from Settings (see Phase 4/5).
Join the candidates using the chosen method (e.g., resultData.lineBreaksJoined or resultData.spacesJoined).
Copy the final string to the clipboard: NSPasteboard.general.string = joinedText.
Provide visual feedback (e.g., briefly change status item icon to a checkmark).
Refactor LaTeX Extraction (App.swift & LatexAPIService.swift):

Create the new function performGeminiExtraction(image: CGImage).
API Key: Fetch the user-provided Gemini API key from secure storage (see Phase 4/5). If no key is set, show an alert prompting the user to go to Settings and abort the extraction.
Image Conversion: Convert the input CGImage to base64 PNG data (similar logic exists in the old extractLatex function using NSImage wrappers, adapt it for CGImage).
API Call: Modify LatexAPIService.extractLatex or create a new function to accept the API key as a parameter instead of reading it from Config. Pass the fetched user API key and the base64 image data.
Swift

// Example modification in LatexAPIService.swift
// func extractLatex(from imageBase64: String, apiKey: String) async throws -> String {
//     ...
//     guard let url = URL(string: "\(Config.geminiEndpoint)?key=\(apiKey)") else { ... }
//     ...
// }

// In App.swift performGeminiExtraction
// let userApiKey = SettingsManager.shared.getGeminiApiKey() ?? "" // Fetch from Keychain
// guard !userApiKey.isEmpty else { /* Show alert */ return }
// let latexResult = try await latexService.extractLatex(from: base64Image, apiKey: userApiKey)
Result Handling:
Get the resulting LaTeX string.
Clean up the string (remove markdown delimiters like ```latex,$$`, etc.) as done previously.
Fetch the user's preferred join method for LaTeX from Settings (see Phase 4/5) - Note: This might be less relevant for LaTeX which is often single-block, but implement for consistency if needed. Default to copying as is.
Copy the final LaTeX string to the clipboard: NSPasteboard.general.string = cleanedLatex.
Provide visual feedback.
Handle potential errors from the API call (network issues, invalid key, etc.) by showing alerts.
Phase 4: Implement Settings UI

Create SettingsView.swift (New File - SwiftUI Recommended):

Define a SwiftUI view to host the settings controls.
Gemini API Key: Add a SecureField labeled "Gemini API Key". Bind its value to a state variable that interacts with the secure storage (Keychain).
Keyboard Shortcuts:
Add sections for "Vision Extraction Shortcut" and "LaTeX Extraction Shortcut".
Use a dedicated control for recording shortcuts. You might need to bridge an AppKit control or use a library like MASShortcut's view component (MASShortcutView). Display the currently set shortcut. Add "Record" and "Clear" buttons.
Join Preferences:
Add sections for "Vision Join Method" and "LaTeX Join Method".
Use a Picker or radio buttons for each, with options "Join with Line Breaks" and "Join with Spaces". Bind the selection to UserDefaults.
Add a "Close" or "Done" button.
Create SettingsWindowController.swift (New File - AppKit):

Manage the presentation of the SettingsView.
Create an NSWindow programmatically or via a Storyboard/XIB.
Set the contentViewController of the window's contentView to an NSHostingController wrapping your SettingsView.
Implement logic to ensure only one settings window is open at a time.
Implement openSettingsWindow() in App.swift:

Instantiate and show the SettingsWindowController.
Bring the application to the foreground using NSApp.activate(ignoringOtherApps: true).
Phase 5: Implement Settings Storage and Logic

Create SettingsManager.swift (New File or Static Methods):

API Key Storage (Keychain):
Implement functions saveGeminiApiKey(_ key: String) and getGeminiApiKey() -> String? using the Security framework (Keychain Services). Store the key securely, associated with your app's bundle ID or a specific service identifier.
Preferences Storage (UserDefaults):
Define keys for UserDefaults (e.g., visionJoinMethodPref, latexJoinMethodPref, visionShortcutData, latexShortcutData).
Implement functions to save/load the join preference (e.g., storing "linebreaks" or "spaces" string).
Implement functions to save/load the keyboard shortcut data (you'll need to serialize/deserialize the key code and modifier flags, possibly as a Dictionary or Data). UserDefaults.standard.set(value, forKey: key) and UserDefaults.standard.value(forKey: key).
Make it Accessible: Use a Singleton pattern (SettingsManager.shared) or static methods for easy access from App.swift and SettingsView.swift.
Bind Settings UI (SettingsView.swift):

Use @State variables for temporary UI state.
On view appear (.onAppear), load current settings from SettingsManager into the @State variables.
When UI controls change (e.g., SecureField text changes, Picker selection changes, shortcut recorded), call the appropriate save functions in SettingsManager. SwiftUI's @AppStorage can simplify binding for UserDefaults. For Keychain and complex shortcut data, manual saving in .onChange or button actions might be needed.
Phase 6: Implement Keyboard Shortcut Handling

Implement Global Shortcut Monitoring (App.swift or a dedicated ShortcutMonitor.swift):
On app launch (applicationDidFinishLaunching), load the saved shortcuts from SettingsManager.
Register global event monitors using NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handleKeyDownEvent).
Inside handleKeyDownEvent(event: NSEvent):
Compare event.keyCode and event.modifierFlags against the loaded shortcut data for both Vision and LaTeX.
If a match is found:
Consume the event if desired (can be tricky with global monitors).
Trigger the corresponding action: triggerVisionExtraction() or triggerLatexExtraction().
Update Monitoring: When shortcuts are changed in the Settings window, unregister the old monitors and register new ones with the updated shortcut data.
Consider Libraries: Libraries like MASShortcut simplify registration, handling potential system conflicts, and recording shortcuts significantly.
Phase 7: Final Touches

Update Localization (Localizable.xcstrings):

Add new strings for the new menu items ("Extract Text (Vision)", "Extract LaTeX (Gemini)", "Settings...").
Add strings for the Settings window labels, options, and any alert messages.
Testing:

Thoroughly test all new functionalities:
Menu items trigger region selection.
Region selection works correctly (captures the right area).
Vision extraction works with selected region and copies with correct join preference.
LaTeX extraction prompts for API key if missing.
LaTeX extraction works with selected region and user API key, copies result.
Settings window opens and closes.
API key saving/loading (check Keychain).
Join preference saving/loading and affecting output.
Keyboard shortcut recording/clearing/saving/loading.
Keyboard shortcuts trigger the correct actions globally.
Quit menu item works.
