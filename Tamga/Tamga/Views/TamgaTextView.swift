import AppKit

/// The NSTextView subclass backing the editor.
///
/// Text transformations live in `TamgaTextView+Transformations.swift`, and code folding
/// lives in `FoldingSupport.swift`.
class TamgaTextView: NSTextView {
    var showInvisibles: Bool = false {
        didSet {
            if showInvisibles != oldValue {
                needsDisplay = true
            }
        }
    }

    private let spaceSymbol = "·"
    private let tabSymbol = "→"
    private let newlineSymbol = "¶"

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNotifications()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupNotifications()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if showInvisibles {
            drawInvisibleCharacters(in: dirtyRect)
        }

        drawFoldIndicators()
    }

    private func drawInvisibleCharacters(in rect: NSRect) {
        guard let layoutManager = layoutManager,
            let textContainer = textContainer,
            let textStorage = textStorage
        else { return }

        let text = string
        let invisibleColor = NSColor.tertiaryLabelColor

        let font = self.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: invisibleColor
        ]

        let glyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)

        // Draw invisible characters
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { [weak self] (_, _, _, charRange, _) in
            guard let self = self else { return }

            let lineString = (text as NSString).substring(with: charRange) as NSString

            // Walk UTF-16 units so the character index matches the layout manager's
            // NSRange semantics; the invisible characters below are all single-unit ASCII.
            for offset in 0..<lineString.length {
                let charIndex = charRange.location + offset
                guard charIndex < textStorage.length else { continue }
                if isFolded(charIndex) { continue }

                var symbol: String?
                switch lineString.character(at: offset) {
                case 0x20: symbol = self.spaceSymbol
                case 0x09: symbol = self.tabSymbol
                case 0x0A: symbol = self.newlineSymbol
                default: break
                }

                if let symbol = symbol {
                    let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
                    let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)

                    let point = NSPoint(
                        x: glyphRect.origin.x + self.textContainerInset.width,
                        y: glyphRect.origin.y + self.textContainerInset.height
                    )

                    symbol.draw(at: point, withAttributes: attributes)
                }
            }
        }
    }

    /// Menu commands reach the text view through NotificationCenter. Each entry pairs
    /// the posted name with the handler that carries it out.
    private static let menuCommandHandlers: [(Notification.Name, Selector)] = [
        (.duplicateLine, #selector(handleDuplicateLine)),
        (.moveLineUp, #selector(handleMoveLineUp)),
        (.moveLineDown, #selector(handleMoveLineDown)),
        (.sortLinesAscending, #selector(handleSortLinesAscending)),
        (.sortLinesDescending, #selector(handleSortLinesDescending)),
        (.removeDuplicateLines, #selector(handleRemoveDuplicateLines)),
        (.removeEmptyLines, #selector(handleRemoveEmptyLines)),
        (.uppercaseSelection, #selector(handleUppercase)),
        (.lowercaseSelection, #selector(handleLowercase)),
        (.capitalizeSelection, #selector(handleCapitalize)),
        (.formatJSON, #selector(handleFormatJSON)),
        (.minifyJSON, #selector(handleMinifyJSON)),
        (.foldCode, #selector(handleFoldCode)),
        (.unfoldCode, #selector(handleUnfoldCode)),
        (.foldAll, #selector(handleFoldAll)),
        (.unfoldAll, #selector(handleUnfoldAll))
    ]

    private func setupNotifications() {
        for (name, selector) in Self.menuCommandHandlers {
            NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Code Folding State (layout-based; never mutates text)

    /// Character ranges currently hidden by folding. Each range covers everything after
    /// a block's opening brace through its matching closing brace. Hiding happens purely
    /// at the layout stage (see `FoldingSupport.swift`) — the text storage is never
    /// modified, so `string`, save, and copy always return the full document.
    var foldedRanges: [NSRange] = []

    /// Last caret location, used to infer movement direction when snapping the caret out
    /// of a folded range.
    var lastCaretLocation: Int = 0

    private var pendingEditLocation: Int = 0
    private var pendingEditOldLength: Int = 0
    private var pendingEditNewLength: Int = 0
    private var hasPendingEdit: Bool = false

    // MARK: - Auto-indent

    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let cursorPos = min(selectedRange().location, ns.length)

        // Current line up to the cursor, computed in UTF-16 units so a non-BMP
        // character earlier in the document does not shift the indentation source.
        let lineRange = ns.lineRange(for: NSRange(location: cursorPos, length: 0))
        let lineContent = ns.substring(with: NSRange(location: lineRange.location, length: cursorPos - lineRange.location))

        // Calculate current indentation
        var indentation = ""
        for char in lineContent {
            if char == " " || char == "\t" {
                indentation.append(char)
            } else {
                break
            }
        }

        // Check if line ends with opening bracket or colon (for languages like Python)
        let trimmedLine = lineContent.trimmingCharacters(in: CharacterSet.whitespaces)
        let shouldAddExtraIndent =
            trimmedLine.hasSuffix("{") || trimmedLine.hasSuffix(":") || trimmedLine.hasSuffix("(") || trimmedLine.hasSuffix("[")

        if shouldAddExtraIndent {
            // Use tabs or 4 spaces based on existing indentation style
            let indentChar = indentation.contains("\t") ? "\t" : "    "
            indentation += indentChar
        }

        // Insert newline with indentation
        super.insertNewline(sender)
        insertText(indentation, replacementRange: selectedRange())
    }

    override func insertTab(_ sender: Any?) {
        // Insert 4 spaces instead of tab for consistency
        insertText("    ", replacementRange: selectedRange())
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Allow standard shortcuts
        if event.modifierFlags.contains(.command) {
            let hasOption = event.modifierFlags.contains(.option)

            switch event.charactersIgnoringModifiers {
            case "a":  // Select All
                selectAll(nil)
                return true
            case "z" where event.modifierFlags.contains(.shift):  // Redo
                undoManager?.redo()
                return true
            case "z":  // Undo
                undoManager?.undo()
                return true
            case "d" where !hasOption:  // Duplicate Line
                duplicateCurrentLine()
                return true
            default:
                break
            }
        }

        // Move line up/down with Option+Up/Down
        if event.modifierFlags.contains(.option) {
            switch event.keyCode {
            case 126:  // Up arrow
                moveCurrentLineUp()
                return true
            case 125:  // Down arrow
                moveCurrentLineDown()
                return true
            default:
                break
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Code Folding Handlers

    @objc private func handleFoldCode() {
        guard window?.firstResponder === self else { return }
        performFoldCurrentBlock()
    }

    @objc private func handleUnfoldCode() {
        guard window?.firstResponder === self else { return }
        performUnfoldAtCursor()
    }

    @objc private func handleFoldAll() {
        guard window?.firstResponder === self else { return }
        performFoldAll()
    }

    @objc private func handleUnfoldAll() {
        guard window?.firstResponder === self else { return }
        performUnfoldAll()
    }

    // MARK: - Code Folding (layout-based overrides)

    /// Keeps the caret out of a folded (hidden) range. All selection changes funnel
    /// through this method, so it covers arrow keys, clicks, and programmatic selection.
    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        guard !foldedRanges.isEmpty else {
            super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
            lastCaretLocation = selectedRange().location
            return
        }
        let adjusted = ranges.map { value -> NSValue in
            let range = value.rangeValue
            guard range.length == 0 else { return value }
            let movingForward = range.location >= lastCaretLocation
            let snapped = adjustedCaretLocation(range.location, movingForward: movingForward)
            return snapped == range.location ? value : NSValue(range: NSRange(location: snapped, length: 0))
        }
        super.setSelectedRanges(adjusted, affinity: affinity, stillSelecting: flag)
        lastCaretLocation = selectedRange().location
    }

    /// Records the pending edit so `didChangeText()` can shift or drop folds.
    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        pendingEditLocation = affectedCharRange.location
        pendingEditOldLength = affectedCharRange.length
        pendingEditNewLength = (replacementString as NSString?)?.length ?? 0
        hasPendingEdit = true
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    /// Maintains fold positions after every edit.
    override func didChangeText() {
        super.didChangeText()
        maintainFoldsAfterEdit()
    }

    /// A click on a folded block's brace or indicator unfolds it.
    override func mouseDown(with event: NSEvent) {
        if !foldedRanges.isEmpty,
            let layoutManager = layoutManager,
            let textContainer = textContainer
        {
            let viewPoint = convert(event.locationInWindow, from: nil)
            let containerPoint = NSPoint(
                x: viewPoint.x - textContainerInset.width,
                y: viewPoint.y - textContainerInset.height)
            let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            if let index = foldedRanges.firstIndex(where: { charIndex == $0.location - 1 || charIndex == $0.location }) {
                foldedRanges.remove(at: index)
                invalidateFoldLayout()
                return
            }
        }
        super.mouseDown(with: event)
    }

    /// Applies the edit recorded by `shouldChangeText(in:replacementString:)` to the
    /// stored folds: folds entirely before the edit shift by the length delta, folds the
    /// edit overlaps are dropped (the block unfolds), folds entirely after are unchanged.
    /// An edit it cannot attribute clears all folds, which is always safe since the text
    /// itself is never altered by folding.
    private func maintainFoldsAfterEdit() {
        guard !foldedRanges.isEmpty else {
            hasPendingEdit = false
            return
        }
        guard hasPendingEdit else {
            clearAllFolds()
            return
        }
        hasPendingEdit = false

        let editStart = pendingEditLocation
        let editEnd = pendingEditLocation + pendingEditOldLength
        let delta = pendingEditNewLength - pendingEditOldLength

        var updated: [NSRange] = []
        for range in foldedRanges {
            let foldStart = range.location
            let foldEnd = range.location + range.length
            if editEnd <= foldStart {
                updated.append(NSRange(location: foldStart + delta, length: range.length))
            } else if editStart >= foldEnd {
                updated.append(range)
            }
        }

        let changed =
            updated.count != foldedRanges.count
            || zip(updated, foldedRanges).contains { !NSEqualRanges($0, $1) }
        foldedRanges = updated
        if changed { invalidateFoldLayout() }
    }
}
