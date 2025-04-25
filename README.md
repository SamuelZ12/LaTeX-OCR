# LaTeX-OCR

A macOS menu bar app that extracts text and LaTeX equations from screen captures using Apple Vision and Google's Gemini API.

## Features

- Extract text using Apple Vision
- Extract LaTeX equations using Gemini API
- No screen recording permissions required
- Simple menu bar interface

## Usage

To extract text or LaTeX equations:

1. Press Control-Shift-Command-4 to capture a screen region (this automatically copies it to clipboard)
2. Click the TextGrabber2 menu bar icon and select either:
   - "Extract Text (Apple Vision)" for general text
   - "Extract LaTeX (Gemini)" for mathematical equations

The extracted text will be automatically copied to your clipboard.

## Requirements

- macOS 10.15 or later
- Gemini API key (for LaTeX extraction)

## Setup

1. Clone the repository
2. Create a `Secrets.plist` file with your Gemini API key
3. Build and run the project in Xcode

## Configuration 

Access settings through the menu bar icon to:

- Enter your Gemini API key
- Configure text/LaTeX output formats
- Set keyboard shortcuts
- Toggle launch at login

## Privacy

This app does not require screen recording permissions as it only processes images that you explicitly share via clipboard using the system screenshot tool.
