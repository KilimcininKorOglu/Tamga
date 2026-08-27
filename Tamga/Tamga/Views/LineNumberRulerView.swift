import AppKit

/// Line number gutter driven by the text view's own layout.
///
/// Numbers are placed at the `NSLayoutManager` line fragment of each line's first
/// character instead of at a fixed row height. A soft-wrapped line therefore keeps a
/// single number next to its first visual row, and a folded block contributes no
/// numbers because its fragments collapse to zero height.
final class LineNumberRulerView: NSRulerView {

    /// Font used for the numbers. Kept slightly smaller than the editor font.
    var numberFont: NSFont = .monospacedSystemFont(ofSize: 10, weight: .regular) {
        didSet { needsDisplay = true }
    }

    var numberColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }

    var gutterColor: NSColor = .controlBackgroundColor {
        didSet { needsDisplay = true }
    }

    private var textView: NSTextView? {
        clientView as? NSTextView
    }

    init(textView: NSTextView, scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
    }

    required init(coder: NSCoder) {
        fatalError("LineNumberRulerView is created in code only")
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        gutterColor.setFill()
        rect.fill()

        guard let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return }

        let text = textView.string as NSString
        let visibleRect = scrollView?.contentView.bounds ?? textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharacterRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: numberColor
        ]

        // Vertical offset between the text view's coordinates and the ruler's.
        let verticalOffset = textView.textContainerInset.height - visibleRect.origin.y

        var lineNumber = lineNumber(at: visibleCharacterRange.location, in: text)
        var characterIndex = text.lineRange(for: NSRange(location: visibleCharacterRange.location, length: 0)).location
        var lastDrawnY: CGFloat = .greatestFiniteMagnitude

        while characterIndex <= text.length {
            let lineRange = text.lineRange(for: NSRange(location: min(characterIndex, text.length), length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)

            if fragmentRect.minY + verticalOffset > rect.maxY { break }

            // A folded line collapses to zero height, and its neighbours share one
            // fragment; drawing only the first number per position keeps them apart.
            let y = fragmentRect.minY + verticalOffset
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
            lineNumber, layoutManager: layoutManager, text: text, verticalOffset: verticalOffset, rect: rect, attributes: attributes)
    }

    /// Draws the number of the empty line that follows a trailing newline, which owns
    /// no glyphs and therefore lives in the layout manager's extra line fragment.
    private func drawTrailingLineNumber(
        _ lineNumber: Int,
        layoutManager: NSLayoutManager,
        text: NSString,
        verticalOffset: CGFloat,
        rect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        guard text.length > 0, text.character(at: text.length - 1) == 0x0A else { return }
        let fragmentRect = layoutManager.extraLineFragmentRect
        guard fragmentRect.height > 0 else { return }
        let y = fragmentRect.minY + verticalOffset
        guard y <= rect.maxY else { return }
        draw(number: lineNumber, atY: y, lineHeight: fragmentRect.height, attributes: attributes)
    }

    private func draw(number: Int, atY y: CGFloat, lineHeight: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        let label = "\(number)" as NSString
        let size = label.size(withAttributes: attributes)
        let point = NSPoint(
            x: ruleThickness - size.width - 6,
            y: y + (lineHeight - size.height) / 2
        )
        label.draw(at: point, withAttributes: attributes)
    }

    // MARK: - Geometry

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

    /// Widens the gutter so the largest line number always fits.
    func updateThickness(forLineCount lineCount: Int) {
        let digits = max(String(max(lineCount, 1)).count, 3)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: numberFont]).width + 14
        if abs(width - ruleThickness) > 0.5 {
            ruleThickness = width
        }
    }
}
