import AppKit

/// Line number gutter driven by the text view's own layout.
///
/// A plain `NSView` overlay, not an `NSRulerView`: turning on `NSScrollView.rulersVisible`
/// with a custom ruler blanks the whole window content on the current SDK, so the gutter
/// lives as a left-pinned subview instead. Numbers sit at the `NSLayoutManager` line
/// fragment of each line's first character, so a soft-wrapped line keeps one number next
/// to its first visual row and a folded block contributes none.
final class GutterView: NSView {
    private weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?

    var numberFont: NSFont = .monospacedSystemFont(ofSize: 10, weight: .regular) {
        didSet { needsDisplay = true }
    }
    var numberColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }
    var gutterColor: NSColor = .controlBackgroundColor {
        didSet { needsDisplay = true }
    }

    /// Text is laid out top-down, so match that to place numbers by fragment Y.
    override var isFlipped: Bool { true }

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("GutterView is created in code only")
    }

    /// Widens the gutter so the largest line number always fits.
    func width(forLineCount lineCount: Int) -> CGFloat {
        let digits = max(String(max(lineCount, 1)).count, 3)
        let sample = String(repeating: "8", count: digits) as NSString
        return sample.size(withAttributes: [.font: numberFont]).width + 14
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        gutterColor.setFill()
        bounds.fill()

        guard let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let scrollView
        else { return }

        let text = textView.string as NSString
        let visibleRect = scrollView.contentView.bounds
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharacterRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: numberColor
        ]

        // Maps a fragment's Y in the text view to the gutter's own coordinates.
        let verticalOffset = textView.textContainerInset.height - visibleRect.origin.y

        var lineNumber = lineNumber(at: visibleCharacterRange.location, in: text)
        var characterIndex = text.lineRange(for: NSRange(location: visibleCharacterRange.location, length: 0)).location
        var lastDrawnY: CGFloat = .greatestFiniteMagnitude

        while characterIndex <= text.length {
            let lineRange = text.lineRange(for: NSRange(location: min(characterIndex, text.length), length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)

            let y = fragmentRect.minY + verticalOffset
            if y > bounds.maxY { break }

            // Folded lines collapse to zero height and share a fragment; draw one number
            // per distinct position so the visible numbers stay apart.
            if fragmentRect.height > 0 && abs(y - lastDrawnY) > 0.5 {
                draw(number: lineNumber, atY: y, lineHeight: fragmentRect.height, attributes: attributes)
                lastDrawnY = y
            }

            lineNumber += 1
            let nextIndex = NSMaxRange(lineRange)
            if nextIndex <= characterIndex { break }
            characterIndex = nextIndex
        }

        drawTrailingLineNumber(
            lineNumber, layoutManager: layoutManager, text: text, verticalOffset: verticalOffset, attributes: attributes)
    }

    /// Draws the number of the empty line that follows a trailing newline, which owns no
    /// glyphs and lives in the layout manager's extra line fragment.
    private func drawTrailingLineNumber(
        _ lineNumber: Int,
        layoutManager: NSLayoutManager,
        text: NSString,
        verticalOffset: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) {
        guard text.length > 0, text.character(at: text.length - 1) == 0x0A else { return }
        let fragmentRect = layoutManager.extraLineFragmentRect
        guard fragmentRect.height > 0 else { return }
        let y = fragmentRect.minY + verticalOffset
        guard y <= bounds.maxY else { return }
        draw(number: lineNumber, atY: y, lineHeight: fragmentRect.height, attributes: attributes)
    }

    private func draw(number: Int, atY y: CGFloat, lineHeight: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        let label = "\(number)" as NSString
        let size = label.size(withAttributes: attributes)
        let point = NSPoint(
            x: bounds.width - size.width - 6,
            y: y + (lineHeight - size.height) / 2
        )
        label.draw(at: point, withAttributes: attributes)
    }

    /// 1-based line number of the line containing `characterIndex`.
    private func lineNumber(at characterIndex: Int, in text: NSString) -> Int {
        guard characterIndex > 0 else { return 1 }
        var number = 1
        var index = 0
        while index < characterIndex {
            let lineRange = text.lineRange(for: NSRange(location: index, length: 0))
            let nextIndex = NSMaxRange(lineRange)
            if nextIndex > characterIndex || nextIndex <= index { break }
            number += 1
            index = nextIndex
        }
        return number
    }
}
