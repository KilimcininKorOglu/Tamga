import AppKit

/// Layout-based code folding for ``TamgaTextView``.
///
/// Folding never mutates the text storage. Instead, the folded character range is
/// recorded in `foldedRanges` and hidden purely at the layout stage:
/// `shouldGenerateGlyphs` emits null (zero-width, non-drawn) glyphs for folded
/// characters, and `shouldUse:forControlCharacterAt:` collapses the line breaks inside
/// a fold so the hidden lines occupy no vertical space. Because the text storage is
/// untouched, `string` (and therefore save/copy) always returns the full document and
/// the syntax tree stays valid.
extension TamgaTextView: NSLayoutManagerDelegate {

    // MARK: - NSLayoutManagerDelegate (glyph hiding)

    /// Replaces glyphs for characters inside a folded range with the null glyph
    /// (invisible, zero advancement). Returns 0 for ranges with nothing folded so the
    /// layout manager performs its default glyph generation.
    public func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard !foldedRanges.isEmpty else { return 0 }

        var containsHidden = false
        for i in 0..<glyphRange.length where isFolded(charIndexes[i]) {
            containsHidden = true
            break
        }
        guard containsHidden else { return 0 }

        let newProps = UnsafeMutablePointer<NSLayoutManager.GlyphProperty>.allocate(capacity: glyphRange.length)
        defer { newProps.deallocate() }
        for i in 0..<glyphRange.length {
            newProps[i] = isFolded(charIndexes[i]) ? .null : props[i]
        }
        layoutManager.setGlyphs(
            glyphs,
            properties: newProps,
            characterIndexes: charIndexes,
            font: font,
            forGlyphRange: glyphRange)
        return glyphRange.length
    }

    /// Collapses control characters (newlines, tabs) inside a folded range to zero
    /// advancement so the hidden lines do not break onto new rows or reserve width.
    public func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldUse action: NSLayoutManager.ControlCharacterAction,
        forControlCharacterAt charIndex: Int
    ) -> NSLayoutManager.ControlCharacterAction {
        isFolded(charIndex) ? .zeroAdvancement : action
    }

    // MARK: - Folded range queries

    /// Whether the character at `charIndex` falls inside any folded (hidden) range.
    func isFolded(_ charIndex: Int) -> Bool {
        for range in foldedRanges where charIndex >= range.location && charIndex < range.location + range.length {
            return true
        }
        return false
    }

    /// Snaps a caret location out of a folded range. A caret strictly inside a fold is
    /// pushed to the fold's trailing edge when moving forward, otherwise to its start.
    func adjustedCaretLocation(_ location: Int, movingForward: Bool) -> Int {
        for range in foldedRanges where location > range.location && location < range.location + range.length {
            return movingForward ? (range.location + range.length) : range.location
        }
        return location
    }

    // MARK: - Fold operations

    /// Folds the innermost brace block at or around the caret.
    func performFoldCurrentBlock() {
        guard let hidden = foldableHiddenRange(around: selectedRange().location), hidden.length > 0 else {
            NSSound.beep()
            return
        }
        for existing in foldedRanges where NSIntersectionRange(existing, hidden).length > 0 || existing.location == hidden.location {
            NSSound.beep()
            return
        }
        foldedRanges.append(hidden)
        foldedRanges.sort { $0.location < $1.location }
        invalidateFoldLayout()
        normalizeSelectionAfterFoldChange()
    }

    /// Unfolds the fold whose header brace or hidden range contains the caret.
    func performUnfoldAtCursor() {
        let caret = selectedRange().location
        if let index = foldedRanges.firstIndex(where: { caret >= $0.location - 1 && caret <= $0.location + $0.length }) {
            foldedRanges.remove(at: index)
            invalidateFoldLayout()
            return
        }
        NSSound.beep()
    }

    /// Folds every top-level brace block in the document.
    func performFoldAll() {
        let text = string as NSString
        let length = text.length
        let openBrace: unichar = 0x7B
        let closeBrace: unichar = 0x7D

        var newFolds: [NSRange] = []
        var index = 0
        while index < length {
            if text.character(at: index) == openBrace {
                var depth = 1
                var cursor = index + 1
                while cursor < length {
                    let character = text.character(at: cursor)
                    if character == openBrace {
                        depth += 1
                    } else if character == closeBrace {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    cursor += 1
                }
                if depth == 0 {
                    let hidden = NSRange(location: index + 1, length: (cursor + 1) - (index + 1))
                    if hidden.length > 0 { newFolds.append(hidden) }
                    index = cursor + 1
                    continue
                }
            }
            index += 1
        }

        guard !newFolds.isEmpty else {
            NSSound.beep()
            return
        }
        foldedRanges = newFolds
        invalidateFoldLayout()
        normalizeSelectionAfterFoldChange()
    }

    /// Unfolds every fold in the document.
    func performUnfoldAll() {
        guard !foldedRanges.isEmpty else {
            NSSound.beep()
            return
        }
        foldedRanges.removeAll()
        invalidateFoldLayout()
    }

    /// Removes all folds without a beep. Used when an out-of-band text mutation (sort,
    /// move, format, external content swap) invalidates stored fold positions.
    func clearAllFolds() {
        guard !foldedRanges.isEmpty else { return }
        foldedRanges.removeAll()
        invalidateFoldLayout()
    }

    // MARK: - Block detection

    /// Returns the character range to hide when folding the block around `position`:
    /// everything after the opening brace through the matching closing brace. The
    /// opening-brace line stays visible. Returns nil when no balanced block is found.
    ///
    /// Works in UTF-16 units (NSRange semantics) so brace offsets stay valid even when
    /// the document contains characters outside the Basic Multilingual Plane.
    private func foldableHiddenRange(around position: Int) -> NSRange? {
        let text = string as NSString
        let length = text.length
        guard length > 0, let openPos = openingBracePosition(around: position, in: text) else { return nil }

        let openBrace: unichar = 0x7B
        let closeBrace: unichar = 0x7D
        var depth = 1
        var cursor = openPos + 1
        while cursor < length {
            let character = text.character(at: cursor)
            if character == openBrace {
                depth += 1
            } else if character == closeBrace {
                depth -= 1
                if depth == 0 { break }
            }
            cursor += 1
        }
        guard depth == 0 else { return nil }
        return NSRange(location: openPos + 1, length: (cursor + 1) - (openPos + 1))
    }

    /// Finds the opening brace to fold: the brace at the caret, else the next brace on
    /// the caret's line, else the nearest brace before the caret.
    private func openingBracePosition(around position: Int, in text: NSString) -> Int? {
        let length = text.length
        guard length > 0 else { return nil }
        let openBrace: unichar = 0x7B
        let newline: unichar = 0x0A
        let start = min(max(position, 0), length)

        if start < length && text.character(at: start) == openBrace { return start }

        var forward = start
        while forward < length {
            let character = text.character(at: forward)
            if character == newline { break }
            if character == openBrace { return forward }
            forward += 1
        }

        var backward = min(start, length - 1)
        while backward >= 0 {
            if text.character(at: backward) == openBrace { return backward }
            backward -= 1
        }
        return nil
    }

    // MARK: - Layout invalidation & selection

    /// Forces the layout manager to regenerate glyphs and layout for the whole document
    /// so folded ranges hide (or reappear). Whole-document invalidation keeps the logic
    /// simple and correct; documents in this editor are small enough for it to be cheap.
    func invalidateFoldLayout() {
        guard let layoutManager = layoutManager,
            let textContainer = textContainer,
            let textStorage = textStorage
        else { return }
        let full = NSRange(location: 0, length: textStorage.length)
        layoutManager.invalidateGlyphs(forCharacterRange: full, changeInLength: 0, actualCharacterRange: nil)
        layoutManager.invalidateLayout(forCharacterRange: full, actualCharacterRange: nil)
        layoutManager.ensureLayout(for: textContainer)
        needsDisplay = true
    }

    /// Moves the caret out of a fold it ended up inside after a fold operation.
    private func normalizeSelectionAfterFoldChange() {
        let caret = selectedRange()
        guard caret.length == 0 else { return }
        if let range = foldedRanges.first(where: { caret.location > $0.location && caret.location < $0.location + $0.length }) {
            setSelectedRange(NSRange(location: range.location, length: 0))
        }
    }

    // MARK: - Fold indicator drawing

    /// Draws a "⋯" badge just after each folded block's opening brace.
    func drawFoldIndicators() {
        guard !foldedRanges.isEmpty,
            let layoutManager = layoutManager,
            let textContainer = textContainer
        else { return }

        let text = string as NSString
        let baseFont = self.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let indicatorFont = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.85, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: indicatorFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let label = "⋯" as NSString
        let labelSize = label.size(withAttributes: attributes)
        let fillColor = NSColor.systemGray.withAlphaComponent(0.22)

        for range in foldedRanges {
            let bracePos = range.location - 1
            guard bracePos >= 0, bracePos < text.length else { continue }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: bracePos)
            let braceRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)

            let horizontalPadding: CGFloat = 4
            let gap: CGFloat = 4
            let pillRect = NSRect(
                x: braceRect.maxX + textContainerInset.width + gap,
                y: braceRect.minY + textContainerInset.height + 1,
                width: labelSize.width + horizontalPadding * 2,
                height: max(braceRect.height - 2, labelSize.height)
            )
            let path = NSBezierPath(roundedRect: pillRect, xRadius: 3, yRadius: 3)
            fillColor.setFill()
            path.fill()

            let textPoint = NSPoint(
                x: pillRect.minX + horizontalPadding,
                y: pillRect.midY - labelSize.height / 2
            )
            label.draw(at: textPoint, withAttributes: attributes)
        }
    }
}
