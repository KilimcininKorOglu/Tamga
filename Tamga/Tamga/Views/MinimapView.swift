import AppKit

/// A right-pinned overview of the whole document: each line is a thin bar sized to its
/// content, with a viewport rectangle over the visible region. Clicking or dragging
/// scrolls the editor to that position.
///
/// It draws a density map, not the real glyphs, so redraws stay cheap on large files.
final class MinimapView: NSView {
    static let width: CGFloat = 72

    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?

    var barColor: NSColor = .secondaryLabelColor
    var viewportColor: NSColor = .systemBlue
    var backgroundColor: NSColor = .controlBackgroundColor

    /// Characters mapped across the full bar width; longer lines clamp to this.
    private let maxLineLength: CGFloat = 100

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.withAlphaComponent(0.4).setFill()
        bounds.fill()

        guard let textView, let container = textView.textContainer, let layoutManager = textView.layoutManager else {
            return
        }

        drawLineBars()

        let totalHeight = layoutManager.usedRect(for: container).height
        drawViewport(totalHeight: totalHeight)
    }

    private func drawLineBars() {
        guard let textView else { return }
        let lines = (textView.string as NSString).components(separatedBy: "\n")
        let lineCount = max(lines.count, 1)
        let lineHeight = min(bounds.height / CGFloat(lineCount), 3)
        let usableWidth = bounds.width - 8

        barColor.withAlphaComponent(0.55).setFill()
        for (index, line) in lines.enumerated() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let indent = CGFloat(line.prefix(while: { $0 == " " || $0 == "\t" }).count)
            let length = min(CGFloat(line.count), maxLineLength)
            let startX = 4 + (min(indent, maxLineLength) / maxLineLength) * usableWidth
            let barWidth = max(((length - indent) / maxLineLength) * usableWidth, 1)
            let y = CGFloat(index) * lineHeight
            NSRect(x: startX, y: y, width: barWidth, height: max(lineHeight - 0.5, 0.6)).fill()
        }
    }

    private func drawViewport(totalHeight: CGFloat) {
        guard totalHeight > 0, let scrollView else { return }
        let visible = scrollView.contentView.bounds
        let viewportY = (visible.origin.y / totalHeight) * bounds.height
        let viewportHeight = min((visible.height / totalHeight) * bounds.height, bounds.height)
        viewportColor.withAlphaComponent(0.18).setFill()
        NSRect(x: 0, y: viewportY, width: bounds.width, height: viewportHeight).fill()
        viewportColor.withAlphaComponent(0.4).setStroke()
        NSBezierPath(rect: NSRect(x: 0.5, y: viewportY, width: bounds.width - 1, height: viewportHeight)).stroke()
    }

    override func mouseDown(with event: NSEvent) { scrollToEvent(event) }
    override func mouseDragged(with event: NSEvent) { scrollToEvent(event) }

    /// Centers the editor's viewport on the clicked fraction of the document height.
    private func scrollToEvent(_ event: NSEvent) {
        guard
            let textView, let scrollView,
            let container = textView.textContainer, let layoutManager = textView.layoutManager
        else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let totalHeight = layoutManager.usedRect(for: container).height
        let visibleHeight = scrollView.contentView.bounds.height
        let fraction = max(0, min(point.y / bounds.height, 1))
        let target = fraction * totalHeight - visibleHeight / 2
        let clamped = max(0, min(target, max(totalHeight - visibleHeight, 0)))
        textView.scroll(NSPoint(x: 0, y: clamped))
        needsDisplay = true
    }
}
