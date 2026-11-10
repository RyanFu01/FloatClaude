import Cocoa

/// The floating window.
///
/// A non-activating panel can become key (so you can type in it) without
/// activating the app. That's what lets it float over a full-screen video
/// without knocking that video out of full screen.
final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = .floating
        // Follow the user across Spaces and appear over full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        minSize = NSSize(width: 300, height: 300)
        isReleasedWhenClosed = false
        // The traffic lights would sit on top of claude.ai's sidebar button.
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(b)?.isHidden = true
        }
        setFrameAutosaveName("FloatClaudeWindow")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Thin grab bar along the top edge for moving the window
/// (the web view covers the title bar, so it can't be dragged directly).
final class DragHandle: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let pill = NSView(frame: NSRect(x: (frame.width - 36) / 2, y: (frame.height - 4) / 2, width: 36, height: 4))
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 2
        pill.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.5).cgColor
        pill.autoresizingMask = [.minXMargin, .maxXMargin]
        addSubview(pill)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

/// Translucent diagonal gradient laid over the frosted glass.
final class TintView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func makeBackingLayer() -> CALayer {
        let g = CAGradientLayer()
        g.startPoint = CGPoint(x: 0, y: 1)   // top-left (layer y axis points up)
        g.endPoint = CGPoint(x: 1, y: 0)     // bottom-right
        return g
    }

    /// `nil` hides the tint entirely.
    func setColors(_ colors: [NSColor]?) {
        guard let g = layer as? CAGradientLayer else { return }
        isHidden = colors == nil
        g.colors = colors?.map(\.cgColor)
    }
}
