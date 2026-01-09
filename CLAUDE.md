# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LaTeX OCR is a macOS menu bar application for screen capture and AI-powered content extraction. It uses customizable prompts with the Google Gemini API to extract content in various formats (LaTeX, Markdown, or custom). Built with Swift and SwiftUI, it's an Xcode project that creates a menu bar-only application.

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
- **App.swift**: Main application delegate, handles menu bar setup, screen capture, dynamic prompt menu, and result processing. Contains HistoryManager for recent captures.
- **Recognizer.swift**: OCR functionality using Apple's Vision framework for offline text extraction
- **GeminiService.swift**: Google Gemini API integration for AI-powered content extraction
- **Config.swift**: Configuration management including Gemini API models and endpoint configuration

### Prompt System
- **Prompt.swift**: Data model for prompts with `id`, `name`, `content`, `copyFormat`, `isBuiltIn`, `isDefault`
- **PromptManager.swift**: Singleton service for CRUD operations on prompts, handles persistence to UserDefaults
- **Built-in prompts**: LaTeX and Markdown (cannot be deleted, content cannot be modified)
- **Custom prompts**: Users can create, edit, and delete their own prompts
- **Per-prompt copy format**: Each prompt has its own output format setting (line breaks, spaces, LaTeX newlines)

### Key Architectural Patterns
- **MainActor usage**: Most classes are marked with `@MainActor` for thread-safe UI updates
- **Combine framework**: Used for reactive updates between PromptManager/SettingsManager and UI
- **Settings management**: Centralized in Settings/ directory with SwiftUI views
- **API key handling**: Supports both UserDefaults storage and Secrets.plist fallback
- **History system**: Maintains up to 10 recent capture results with prompt information

### Directory Structure
```
LaTeXOCR/Sources/
├── App.swift                    # Main app delegate and menu bar logic
├── Config.swift                 # Configuration and Gemini model definitions
├── Recognizer.swift             # OCR using Vision framework
├── Models/
│   └── Prompt.swift             # Prompt data model with built-in prompts
├── Services/
│   ├── GeminiService.swift      # Gemini API integration
│   └── PromptManager.swift      # Prompt CRUD and persistence
├── Settings/
│   ├── SettingsView.swift       # Main settings UI
│   ├── SettingsManager.swift    # Settings persistence
│   ├── ShortcutMonitor.swift    # Global keyboard shortcuts
│   ├── PromptListView.swift     # Prompt management UI
│   └── PromptEditorView.swift   # Create/edit prompt UI
└── Extensions/                  # AppKit/Foundation extensions
```

### Key Dependencies
- **Apple Vision**: For OCR text recognition (offline)
- **Google Gemini API**: For AI-powered extraction (requires API key)
- **AppKit**: Menu bar integration and system services
- **SwiftUI**: Settings interface and prompt management UI
- **Combine**: Reactive updates for settings and prompts
- **ServiceManagement**: App service management

### Configuration Files
- **Build.xcconfig**: Contains bundle identifier and version info
- **Info.plist**: App metadata, includes screen recording permission description
- **Secrets.plist**: Optional file for hardcoded API keys (not in repo)

## Development Notes

### Prompt System
- Prompts are stored in UserDefaults as JSON-encoded data
- Built-in prompts have stable UUIDs defined in Prompt.swift
- PromptManager handles migration from old settings format
- Menu bar dynamically rebuilds when prompts change (via Combine)

### Shortcut System
- `ShortcutAction` enum: `.visionOCR` (offline text) and `.defaultPrompt` (AI extraction)
- ShortcutMonitor uses Carbon Event API for global hotkeys
- Default shortcuts: Cmd+T (text), Cmd+L (default prompt)

### API Integration
- GeminiService accepts prompt content as parameter (not hardcoded)
- Gemini models defined in Config.swift with ID and user-friendly labels
- API endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- API key precedence: UserDefaults → Secrets.plist → empty string

### Menu Bar Application
- Uses `LSUIElement: true` in Info.plist to create menu bar-only app
- No dock icon or standard app window
- Requires Screen Recording permission for capture functionality
- Menu structure: Extract Text, [Prompts with checkmark on default], History, Settings, Quit

### Extensions Pattern
- Heavy use of extensions in Extensions/ directory for AppKit/Foundation classes
- Common pattern for utility methods and convenience functions
