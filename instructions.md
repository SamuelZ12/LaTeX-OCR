## Testing Guide

Before deploying, test the following functionality:

1. Menu Items
- Click status bar icon to open menu
- Verify all menu items are properly localized
- Check that keyboard shortcuts are displayed correctly

2. Region Selection
- Click "Extract Text (Vision)" and verify selection overlay appears
- Test ESC key cancels selection
- Verify selection rectangle draws correctly
- Check that clicking and dragging works smoothly

3. Vision Extraction
- Select region with text
- Verify text is detected and copied to clipboard
- Check that empty regions show proper error message
- Test with different types of text (plain, formatted, etc.)

4. LaTeX Extraction
- Verify API key warning when not configured
- Set API key in settings
- Select region with mathematical expression
- Check LaTeX output format and clipboard content
- Test error handling for invalid images

5. Settings Window
- Open settings from menu
- Test API key saving/loading
- Verify join method selections persist
- Test keyboard shortcut recording
- Check window positioning and styling

6. Global Shortcuts
- Set shortcuts for both extraction types
- Test shortcuts work when app isn't focused
- Verify shortcuts trigger correct extraction type
- Check conflict handling with system shortcuts

7. Error Handling
- Test network errors (disable WiFi)
- Verify proper error messages display
- Check logging functionality
- Test recovery from errors

8. Configuration
- Verify network permissions work
- Test API endpoint configuration
- Check secure storage of API key

## Setup Guide

1. Obtain Gemini API Key
- Visit Google Cloud Console
- Create new project or select existing
- Enable Vertex AI API
- Create API credentials
- Copy API key

2. Configure TextGrabber2
- Open app
- Go to Settings
- Paste API key in secure field
- Configure preferred join methods
- Set keyboard shortcuts (optional)

3. Network Access
Ensure Info.entitlements includes:
