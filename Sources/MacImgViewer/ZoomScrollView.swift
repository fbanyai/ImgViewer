import AppKit

/// Scroll view whose wheel zooms around the pointer instead of scrolling.
final class ZoomScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        guard event.momentumPhase.isEmpty, let documentView else { return }

        // Use the physical direction so "roll away" always zooms in, regardless of natural scrolling.
        var dy = event.scrollingDeltaY
        if event.isDirectionInvertedFromDevice { dy = -dy }
        guard dy != 0 else { return }

        let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.01 : 0.15
        let factor = exp(dy * sensitivity)
        let point = documentView.convert(event.locationInWindow, from: nil)
        setMagnification(magnification * factor, centeredAt: point)
    }
}

/// Keeps the document centered when it is smaller than the viewport.
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return rect }
        let doc = documentView.frame
        if rect.width > doc.width { rect.origin.x = (doc.width - rect.width) / 2 }
        if rect.height > doc.height { rect.origin.y = (doc.height - rect.height) / 2 }
        return rect
    }
}

/// Image view that pans its scroll view on drag and resets zoom on double-click.
final class PanningImageView: NSImageView {
    var onDoubleClick: (() -> Void)?

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onDoubleClick?() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let scrollView = enclosingScrollView else { return }
        let clip = scrollView.contentView
        let scale = scrollView.magnification
        var origin = clip.bounds.origin
        origin.x -= event.deltaX / scale
        origin.y += event.deltaY / scale
        let constrained = clip.constrainBoundsRect(NSRect(origin: origin, size: clip.bounds.size))
        clip.scroll(to: constrained.origin)
        scrollView.reflectScrolledClipView(clip)
    }
}
