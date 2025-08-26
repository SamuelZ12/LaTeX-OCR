# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LaTeX OCR is a macOS menu bar application that performs OCR on screen captures, specializing in extracting mathematical equations into LaTeX format using the Google Gemini API. Built with Swift and SwiftUI, it's an Xcode project that creates a menu bar-only application.

## Development Commands

### Building and Running
- **Open project:** `open LaTeXOCR.xcodeproj`
- **Build:** Use Xcode's `Cmd+B` or select Product > Build
- **Run/Debug:** Use Xcode's `Cmd+R` or select Product > Run
- **Archive for distribution:** Product > Archive (creates .dmg for distribution)

### Project Structure
- **Main scheme:** `LaTeXOCR` (ensure this is selected in Xcode)
- **Target:** macOS 14.0+ 
- **Bundle ID:** `app.samuelz12.latexocr-dev` (defined in Build.xcconfig)
- **Current version:** 1.2.0 (MARKETING_VERSION in Build.xcconfig)

## Architecture

### Core Components
- **App.swift**: Main application delegate, handles menu bar setup, screen capture initiation, and result processing. Contains HistoryManager for recent captures.
- **Recognizer.swift**: OCR functionality using Apple's Vision framework for text extraction
- **LatexAPIService.swift**: Google Gemini API integration for LaTeX conversion
- **Config.swift**: Configuration management including Gemini API models and endpoint configuration

### Key Architectural Patterns
- **MainActor usage**: Most classes are marked with `@MainActor` for thread-safe UI updates
- **Settings management**: Centralized in Settings/ directory with SwiftUI views
- **API key handling**: Supports both Keychain storage (UserDefaults) and Secrets.plist fallback
- **History system**: Maintains up to 10 recent capture results with timestamps

### Directory Structure
```
LaTeXOCR/Sources/
├── App.swift                    # Main app delegate and menu bar logic
├── Config.swift                 # Configuration and Gemini model definitions  
├── Recognizer.swift            # OCR using Vision framework
├── Services/
│   └── LatexAPIService.swift   # Gemini API integration
├── Settings/                   # SwiftUI settings interface
│   ├── SettingsView.swift      # Main settings UI
│   ├── SettingsManager.swift   # Settings persistence
│   └── ShortcutMonitor.swift   # Global keyboard shortcuts
└── Extensions/                 # AppKit/Foundation extensions
```

### Key Dependencies
- **Apple Vision**: For OCR text recognition
- **Google Gemini API**: For LaTeX conversion (requires API key)
- **AppKit**: Menu bar integration and system services
- **SwiftUI**: Settings interface
- **ServiceManagement**: App service management

### Configuration Files
- **Build.xcconfig**: Contains bundle identifier and version info
- **Info.plist**: App metadata, includes screen recording permission description
- **Secrets.plist**: Optional file for hardcoded API keys (not in repo)

## Development Notes

### API Integration
- Gemini models are defined in Config.swift with both ID and user-friendly labels
- API endpoint construction uses model ID: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- API key precedence: UserDefaults → Secrets.plist → empty string

### Menu Bar Application
- Uses `LSUIElement: true` in Info.plist to create menu bar-only app
- No dock icon or standard app window
- Requires Screen Recording permission for capture functionality

### Extensions Pattern
- Heavy use of extensions in Extensions/ directory for AppKit/Foundation classes
- Common pattern for utility methods and convenience functions