# LaTeX OCR

<img src="Icon.png" alt="LaTeX OCR Icon" width="64"/>

A simple macOS menu bar application to perform OCR on screen captures, with a special focus on extracting mathematical equations into LaTeX format using the Google Gemini API.

## Features

* **Menu Bar Convenience:** Lives in your menu bar for quick access.
* **Screen Capture:** Use a global keyboard shortcut or the menu bar item to capture any portion of your screen.
* **Text Extraction (OCR):** Uses Apple's built-in Vision framework to accurately recognize and extract plain text from captures.
* **LaTeX Extraction:** Leverages the Google Gemini API to convert mathematical equations within captures into LaTeX code.
* **Clipboard Integration:** Automatically copies the extracted text or LaTeX to your clipboard.
* **Customizable Shortcuts:** Set your own global keyboard shortcuts for both text and LaTeX extraction via the Settings panel.
* **Configurable Formatting:** Choose whether multi-line text/LaTeX results are joined with spaces or line breaks.
* **Recent History:** Access recently captured results directly from the menu bar.
* **API Key Management:** Securely enter and store your Google Gemini API key via the Settings panel.

## Requirements

* **macOS:** Version 14.0 (Sonoma) or later.
* **Google Gemini API Key:** Required **only** for the LaTeX extraction feature. You can get a free key from [Google AI Studio](https://makersuite.google.com/app/apikey).
* **Xcode:** Version 16.0 or later (if building from source).

## Installation & Usage

1.  **Download:** Get the latest release `.dmg` file from the [**GitHub Releases page**](https://github.com/SamuelZ12/LaTeX-OCR/releases/latest). *(Link will work once you create releases)*
2.  **Mount:** Open the downloaded `.dmg` file.
3.  **Install:** Drag the `LaTeXOCR.app` icon into your Applications folder.
4.  **Eject:** You can eject the `.dmg` file in Finder after installation.

**Important Note for macOS Users (Gatekeeper):**

Because this application is distributed for free and is not registered with Apple through their paid developer program, macOS Gatekeeper will show a warning when you try to open it for the first time.

* **First Launch Attempt:** When you double-click LaTeX OCR, you will likely see a message saying "`LaTeXOCR` cannot be opened because the developer cannot be verified." or similar. The only options might be "Move to Trash" or "Cancel".
* **How to Open Anyway (Do this only the first time):**
    1.  **Do not** double-click the app yet.
    2.  Go to your **Applications folder** in **Finder**.
    3.  Locate `LaTeXOCR.app`.
    4.  **Right-click** (or hold **Control** and click) on the `LaTeXOCR.app` icon.
    5.  Select **"Open"** from the menu that appears.
    6.  A warning dialog will appear again, but this time it will have an **"Open"** button. Click it.

* **Subsequent Launches:** After performing the "Right-click -> Open" step once, macOS remembers your choice, and you can launch LaTeX OCR normally by double-clicking it from your Applications folder or using Spotlight.

**Using the App:**

1.  **Launch the App:** (After handling the Gatekeeper step above). LaTeX OCR will appear in your macOS menu bar.
2.  **Grant Permissions:** On the first *successful* launch, you'll be prompted to grant Screen Recording permission. This is necessary for the screen capture functionality. Follow the prompts in System Settings.
3.  **Capture:**
    * Click the menu bar icon and select "Extract Text" or "Extract LaTeX".
    * Alternatively, use the configured global keyboard shortcuts (defaults are Cmd+T for Text, Cmd+L for LaTeX).
4.  **Select Area:** Your cursor will turn into a crosshair. Click and drag to select the area of the screen you want to capture.
5.  **Result:**
    * A sound will play upon successful capture and processing.
    * The extracted text or LaTeX code will be automatically copied to your clipboard.
    * The status bar icon will briefly change to a checkmark.
6.  **History:** Click the menu bar icon, go to "Recent Captures" to view and re-copy previous results.
7.  **Settings:**
    * Click the menu bar icon and select "Settings".
    * **API Key:** Enter your Google Gemini API Key here for LaTeX extraction.
    * **Shortcuts:** Configure your preferred global keyboard shortcuts.
    * **Formatting:** Choose how multi-line results should be joined when copied.

## Building from Source

If you prefer to build the application yourself:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/SamuelZ12/LaTeX-OCR.git
    cd LaTeX-OCR
    ```
2.  **Open in Xcode:**
    ```bash
    open LaTeXOCR.xcodeproj
    ```
3.  **Select Scheme:** Ensure the `LaTeXOCR` scheme is selected.
4.  **Build/Run:** Press `Cmd+B` to build or `Cmd+R` to run the application directly on your Mac. (Apps you build yourself typically don't trigger the same Gatekeeper warnings on your own machine).
5.  **(Required for LaTeX)** **Configure API Key:** After running the built app, open its Settings panel from the menu bar icon and enter your Google Gemini API key.

## Code Structure Overview

* `LaTeXOCR/Sources/App.swift`: Main application delegate, menu bar setup, capture initiation, and result handling.
* `LaTeXOCR/Sources/Recognizer.swift`: Handles text OCR using Apple's Vision framework.
* `LaTeXOCR/Sources/Services/LatexAPIService.swift`: Manages interaction with the Google Gemini API for LaTeX extraction.
* `LaTeXOCR/Sources/Settings/`: Contains SwiftUI views (`SettingsView.swift`), window controller (`SettingsWindowController.swift`), settings logic (`SettingsManager.swift`), and shortcut handling (`ShortcutMonitor.swift`).
* `LaTeXOCR/Sources/Extensions/`: Utility extensions for various AppKit/Foundation classes.
* `LaTeXOCR/Info.plist`: Application metadata and permission descriptions.
* `LaTeXOCR.xcodeproj`: Xcode project file.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built on top of [TextGrabber2](https://github.com/TextGrabber2-app/TextGrabber2) by cyanzhong
