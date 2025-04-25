import AppKit
import CoreGraphics

/// Handles screen capture functionality
final class ScreenCapture: NSObject {
    typealias CompletionHandler = (CGImage?) -> Void
    
    private var completion: CompletionHandler?
    private var window: NSWindow?
    private var selectionView: NSView?
    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    
    func selectRegion(completion: @escaping CompletionHandler) {
        self.completion = completion
        
        let screens = NSScreen.screens
        let mainScreen = NSScreen.main ?? screens.first
        
        guard let screen = mainScreen else {
            completion(nil)
            return
        }
        
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        window?.backgroundColor = .clear
        window?.level = .screenSaver
        window?.isOpaque = false
        
        let view = SelectionView()
        view.delegate = self
        window?.contentView = view
        selectionView = view
        
        window?.makeKeyAndOrderFront(nil)
    }
    
    private func captureSelectedRegion() {
        guard let window = window,
              let currentRect = currentRect else {
            cleanup()
            return
        }
        
        let cgRect = CGRect(x: currentRect.minX,
                           y: window.screen?.frame.height ?? 0 - currentRect.maxY,
                           width: currentRect.width,
                           height: currentRect.height)
        
        if let cgImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming]
        ) {
            completion?(cgImage)
        } else {
            completion?(nil)
        }
        
        cleanup()
    }
    
    private func cleanup() {
        window?.close()
        window = nil
        selectionView = nil
        startPoint = nil
        currentRect = nil
    }
}

extension ScreenCapture: SelectionViewDelegate {
    func selectionBegan(at point: NSPoint) {
        startPoint = point
    }
    
    func selectionChanged(to point: NSPoint) {
        guard let start = startPoint else { return }
        
        let minX = min(start.x, point.x)
        let minY = min(start.y, point.y)
        let width = abs(start.x - point.x)
        let height = abs(start.y - point.y)
        
        currentRect = NSRect(x: minX, y: minY, width: width, height: height)
        selectionView?.setNeedsDisplay(currentRect ?? .zero)
    }
    
    func selectionEnded() {
        captureSelectedRegion()
    }
    
    func selectionCancelled() {
        completion?(nil)
        cleanup()
    }
}

protocol SelectionViewDelegate: AnyObject {
    func selectionBegan(at point: NSPoint)
    func selectionChanged(to point: NSPoint)
    func selectionEnded()
    func selectionCancelled()
}

private class SelectionView: NSView {
    weak var delegate: SelectionViewDelegate?
    private var isSelecting = false
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
    }
    
    override func mouseDown(with event: NSEvent) {
        isSelecting = true
        let point = convert(event.locationInWindow, from: nil)
        delegate?.selectionBegan(at: point)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isSelecting else { return }
        let point = convert(event.locationInWindow, from: nil)
        delegate?.selectionChanged(to: point)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isSelecting else { return }
        isSelecting = false
        delegate?.selectionEnded()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            delegate?.selectionCancelled()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
}
