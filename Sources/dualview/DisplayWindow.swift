import AppKit

final class ImageView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    var overlayText: String? {
        didSet { needsDisplay = true }
    }
    var overlayFont = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular) {
        didSet { needsDisplay = true }
    }
    var rotation = QuarterTurn.none {
        didSet { needsDisplay = true }
    }
    var progressFraction: CGFloat? {
        didSet { needsDisplay = true }
    }
    var keyHandler: ((NSEvent) -> Void)?
    var clickHandler: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func keyDown(with event: NSEvent) {
        keyHandler?(event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        if clickHandler != nil {
            clickHandler?(!event.modifierFlags.contains(.shift))
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        clickHandler?(false)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext.current else {
            NSGraphicsContext.restoreGraphicsState()
            return
        }
        let contentBounds: NSRect
        switch rotation {
        case .none:
            contentBounds = bounds
        case .clockwise, .counterclockwise:
            context.cgContext.translateBy(x: bounds.midX, y: bounds.midY)
            context.cgContext.rotate(by: rotation == .clockwise ? -.pi / 2 : .pi / 2)
            contentBounds = NSRect(
                x: -bounds.height / 2,
                y: -bounds.width / 2,
                width: bounds.height,
                height: bounds.width
            )
        }

        if let image, image.size.width > 0, image.size.height > 0 {
            drawImage(image, in: contentBounds)
        }

        drawProgressBar(in: contentBounds)
        drawPathOverlay(in: contentBounds)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawImage(_ image: NSImage, in contentBounds: NSRect) {
        let scale = min(
            contentBounds.width / image.size.width,
            contentBounds.height / image.size.height
        )
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = NSRect(
            x: contentBounds.midX - size.width / 2,
            y: contentBounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: rect,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    private func drawProgressBar(in contentBounds: NSRect) {
        guard let progressFraction else { return }
        let fraction = min(max(progressFraction, 0), 1)
        let height: CGFloat = 3
        let track = NSRect(
            x: contentBounds.minX,
            y: contentBounds.minY,
            width: contentBounds.width,
            height: height
        )
        NSColor(calibratedWhite: 1, alpha: 0.20).setFill()
        track.fill()
        NSColor(calibratedWhite: 1, alpha: 0.88).setFill()
        NSRect(
            x: contentBounds.minX,
            y: contentBounds.minY,
            width: contentBounds.width * fraction,
            height: height
        ).fill()
    }

    private func drawPathOverlay(in contentBounds: NSRect) {
        guard let overlayText, !overlayText.isEmpty else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        let attributed = NSAttributedString(
            string: overlayText,
            attributes: [
                .font: overlayFont,
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph,
            ]
        )
        let horizontalMargin: CGFloat = 22
        let verticalMargin: CGFloat = 18
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 6
        let availableWidth = max(80, contentBounds.width - horizontalMargin * 2)
        let measured = attributed.boundingRect(
            with: NSSize(width: .greatestFiniteMagnitude, height: overlayFont.pointSize * 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textHeight = ceil(overlayFont.ascender - overlayFont.descender + overlayFont.leading)
        let boxWidth = min(availableWidth, ceil(measured.width) + horizontalPadding * 2)
        let boxHeight = textHeight + verticalPadding * 2
        let boxRect = NSRect(
            x: contentBounds.minX + horizontalMargin,
            y: contentBounds.minY + verticalMargin,
            width: boxWidth,
            height: boxHeight
        )

        NSColor(calibratedWhite: 0, alpha: 0.72).setFill()
        NSBezierPath(roundedRect: boxRect, xRadius: 6, yRadius: 6).fill()
        attributed.draw(
            with: boxRect.insetBy(dx: horizontalPadding, dy: verticalPadding),
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine]
        )
    }
}

final class DisplayWindow: NSWindow {
    let imageView = ImageView(frame: .zero)

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: false)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        isRestorable = false
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = imageView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        imageView.keyHandler?(event)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            makeKey()
            makeFirstResponder(imageView)
        }
        super.sendEvent(event)
    }
}
