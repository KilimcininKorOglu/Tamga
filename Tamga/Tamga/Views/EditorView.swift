import AppKit
import SwiftUI

/// Main text editor view with line numbers and syntax highlighting
struct EditorView: View {
    @Binding var text: String
    let language: SyntaxLanguage
    let showLineNumbers: Bool
    let isWordWrapEnabled: Bool
    let fontSize: CGFloat
    let fontName: String
    var goToPosition: Int?
    var showInvisibleCharacters: Bool = false
    var onCursorPositionChange: (Int) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @State private var lineCount: Int = 1

    var body: some View {
        // Line numbers are drawn by the scroll view's own ruler, so they follow the
        // real text layout: a soft-wrapped line keeps one number, and a folded block
        // contributes none.
        HighlightedTextEditor(
            text: $text,
            language: language,
            isDarkMode: colorScheme == .dark,
            fontSize: fontSize,
            fontName: fontName,
            isWordWrapEnabled: isWordWrapEnabled,
            showInvisibleCharacters: showInvisibleCharacters,
            showLineNumbers: showLineNumbers,
            goToPosition: goToPosition,
            onLineCountChange: { count in
                lineCount = count
            },
            onCursorPositionChange: onCursorPositionChange
        )
    }
}

// MARK: - Highlighted Text Editor (NSViewRepresentable)

struct HighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let language: SyntaxLanguage
    let isDarkMode: Bool
    let fontSize: CGFloat
    let fontName: String
    let isWordWrapEnabled: Bool
    let showInvisibleCharacters: Bool
    let showLineNumbers: Bool
    let goToPosition: Int?
    let onLineCountChange: (Int) -> Void
    let onCursorPositionChange: (Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = TamgaTextView()

        textView.showInvisibles = showInvisibleCharacters
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Layout-based code folding hides glyphs through the layout manager delegate.
        // Contiguous layout keeps fold collapse/restore deterministic.
        textView.layoutManager?.delegate = textView
        textView.layoutManager?.allowsNonContiguousLayout = false

        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.typingAttributes = [.font: font]

        // Set background and text colors based on theme
        updateColors(textView: textView, isDarkMode: isDarkMode)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !isWordWrapEnabled
        scrollView.autohidesScrollers = true

        if isWordWrapEnabled {
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        } else {
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        // Line numbers live in the scroll view's vertical ruler so they follow the
        // layout manager instead of an assumed row height.
        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = showLineNumbers
        context.coordinator.lineNumberRuler = ruler
        context.coordinator.updateRulerAppearance(fontSize: fontSize, isDarkMode: isDarkMode)

        // The ruler must repaint while scrolling, because it draws only the visible lines.
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TamgaTextView else { return }

        // Update invisible characters setting
        if textView.showInvisibles != showInvisibleCharacters {
            textView.showInvisibles = showInvisibleCharacters
            textView.needsDisplay = true
        }

        // Update text if changed externally
        if textView.string != text {
            // Stored fold positions belong to the previous content; drop them before
            // swapping in new text (e.g. switching tabs on a reused text view).
            textView.clearAllFolds()
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        // Update font
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font

        // Update word wrap
        if isWordWrapEnabled {
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentView.bounds.width - 16,
                height: CGFloat.greatestFiniteMagnitude
            )
            scrollView.hasHorizontalScroller = false
        } else {
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            scrollView.hasHorizontalScroller = true
        }

        // Update colors for dark mode
        updateColors(textView: textView, isDarkMode: isDarkMode)

        // Update the line number gutter
        scrollView.rulersVisible = showLineNumbers
        context.coordinator.updateRulerAppearance(fontSize: fontSize, isDarkMode: isDarkMode)
        context.coordinator.refreshLineNumbers()

        // Apply syntax highlighting
        context.coordinator.applySyntaxHighlighting(language: language, isDarkMode: isDarkMode)

        // Handle go to position
        if let position = goToPosition, position != context.coordinator.lastGoToPosition {
            context.coordinator.lastGoToPosition = position
            context.coordinator.scrollToPosition(position)
        }
    }

    private func updateColors(textView: NSTextView, isDarkMode: Bool) {
        if isDarkMode {
            textView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            textView.insertionPointColor = NSColor.white
        } else {
            textView.backgroundColor = NSColor.textBackgroundColor
            textView.insertionPointColor = NSColor.textColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        weak var lineNumberRuler: LineNumberRulerView?
        var lastGoToPosition: Int?

        private let highlighter = SyntaxHighlighter.shared
        private let treeSitterController = TreeSitterHighlightController()
        private var isUpdating = false

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func scrollToPosition(_ position: Int) {
            guard let textView = textView else { return }
            let text = textView.string
            let safePosition = min(position, text.count)
            let range = NSRange(location: safePosition, length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView, !isUpdating else { return }
            parent.text = textView.string
            updateLineCount()
            refreshLineNumbers()
            applySyntaxHighlighting(language: parent.language, isDarkMode: parent.isDarkMode)
        }

        /// Reports the caret offset so the status bar can show line and column.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.onCursorPositionChange(textView.selectedRange().location)
        }

        /// Repaints the gutter and widens it when the line count grows a digit.
        func refreshLineNumbers() {
            guard let lineNumberRuler else { return }
            lineNumberRuler.updateThickness(forLineCount: currentLineCount())
            lineNumberRuler.needsDisplay = true
        }

        func updateRulerAppearance(fontSize: CGFloat, isDarkMode: Bool) {
            guard let lineNumberRuler else { return }
            lineNumberRuler.numberFont = .monospacedSystemFont(ofSize: max(fontSize - 2, 9), weight: .regular)
            lineNumberRuler.numberColor =
                isDarkMode
                ? NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1)
                : NSColor.secondaryLabelColor
            lineNumberRuler.gutterColor =
                isDarkMode
                ? NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
                : NSColor.controlBackgroundColor
        }

        private func currentLineCount() -> Int {
            guard let textView = textView else { return 1 }
            let text = textView.string
            return text.isEmpty ? 1 : text.components(separatedBy: .newlines).count
        }

        func applySyntaxHighlighting(language: SyntaxLanguage, isDarkMode: Bool) {
            guard let textView = textView else { return }

            let font =
                NSFont(name: parent.fontName, size: parent.fontSize)
                ?? NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)

            // Tree-sitter path for migrated languages: Neon styles incrementally via
            // temporary attributes and resolves embedded (injected) languages. When it
            // takes over, skip the regex pass entirely.
            if treeSitterController.configure(textView: textView, language: language, isDarkMode: isDarkMode, font: font) {
                return
            }

            // Regex fallback for non-migrated languages.
            guard !textView.string.isEmpty else { return }

            isUpdating = true
            defer { isUpdating = false }

            let text = textView.string
            let selectedRanges = textView.selectedRanges
            let scrollPosition = scrollView?.contentView.bounds.origin ?? .zero

            let attributedString = highlighter.highlight(
                text: text,
                language: language,
                isDarkMode: isDarkMode
            )

            textView.textStorage?.setAttributedString(attributedString)

            // Restore selection and scroll
            textView.selectedRanges = selectedRanges
            scrollView?.contentView.scroll(to: scrollPosition)
        }

        func updateLineCount() {
            guard let textView = textView else { return }
            let text = textView.string
            let lineCount = text.isEmpty ? 1 : text.components(separatedBy: .newlines).count
            parent.onLineCountChange(lineCount)
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            lineNumberRuler?.needsDisplay = true
        }
    }
}

// MARK: - Custom Text View

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

            let lineString = (text as NSString).substring(with: charRange)

            for (index, char) in lineString.enumerated() {
                let charIndex = charRange.location + index
                guard charIndex < text.count else { continue }
                if isFolded(charIndex) { continue }

                var symbol: String?
                if char == " " {
                    symbol = self.spaceSymbol
                } else if char == "\t" {
                    symbol = self.tabSymbol
                } else if char == "\n" {
                    symbol = self.newlineSymbol
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

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDuplicateLine),
            name: .duplicateLine,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMoveLineUp),
            name: .moveLineUp,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMoveLineDown),
            name: .moveLineDown,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSortLinesAscending),
            name: .sortLinesAscending,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSortLinesDescending),
            name: .sortLinesDescending,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoveDuplicateLines),
            name: .removeDuplicateLines,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUppercase),
            name: .uppercaseSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLowercase),
            name: .lowercaseSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCapitalize),
            name: .capitalizeSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFormatJSON),
            name: .formatJSON,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMinifyJSON),
            name: .minifyJSON,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFoldCode),
            name: .foldCode,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnfoldCode),
            name: .unfoldCode,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFoldAll),
            name: .foldAll,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnfoldAll),
            name: .unfoldAll,
            object: nil
        )
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

    // MARK: - Sort & Transform Handlers

    @objc private func handleSortLinesAscending() {
        guard window?.firstResponder === self else { return }
        sortLines(ascending: true)
    }

    @objc private func handleSortLinesDescending() {
        guard window?.firstResponder === self else { return }
        sortLines(ascending: false)
    }

    @objc private func handleRemoveDuplicateLines() {
        guard window?.firstResponder === self else { return }
        removeDuplicateLines()
    }

    @objc private func handleUppercase() {
        guard window?.firstResponder === self else { return }
        changeCase(.uppercase)
    }

    @objc private func handleLowercase() {
        guard window?.firstResponder === self else { return }
        changeCase(.lowercase)
    }

    @objc private func handleCapitalize() {
        guard window?.firstResponder === self else { return }
        changeCase(.capitalize)
    }

    @objc private func handleFormatJSON() {
        guard window?.firstResponder === self else { return }
        formatJSON(minify: false)
    }

    @objc private func handleMinifyJSON() {
        guard window?.firstResponder === self else { return }
        formatJSON(minify: true)
    }

    @objc private func handleDuplicateLine() {
        guard window?.firstResponder === self else { return }
        duplicateCurrentLine()
    }

    @objc private func handleMoveLineUp() {
        guard window?.firstResponder === self else { return }
        moveCurrentLineUp()
    }

    @objc private func handleMoveLineDown() {
        guard window?.firstResponder === self else { return }
        moveCurrentLineDown()
    }

    // MARK: - Auto-indent

    override func insertNewline(_ sender: Any?) {
        let text = string
        let cursorPos = selectedRange().location

        // Find the current line content before cursor
        let lines = text.components(separatedBy: "\n")
        var currentPos = 0
        var lineContent = ""

        for line in lines {
            let lineEnd = currentPos + line.count
            if cursorPos <= lineEnd {
                // Get the part of the line before cursor
                let cursorOffsetInLine = cursorPos - currentPos
                let endIndex = line.index(line.startIndex, offsetBy: min(cursorOffsetInLine, line.count))
                lineContent = String(line[line.startIndex..<endIndex])
                break
            }
            currentPos = lineEnd + 1  // +1 for newline
        }

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

    private func duplicateCurrentLine() {
        clearAllFolds()
        let text = string
        let cursorPos = selectedRange().location
        let lines = text.components(separatedBy: "\n")

        // Find which line the cursor is on
        var currentPos = 0
        var lineIndex = 0
        for (index, line) in lines.enumerated() {
            let lineEnd = currentPos + line.count
            if cursorPos <= lineEnd || index == lines.count - 1 {
                lineIndex = index
                break
            }
            currentPos = lineEnd + 1
        }

        // Duplicate the line
        var newLines = lines
        newLines.insert(lines[lineIndex], at: lineIndex + 1)

        let newContent = newLines.joined(separator: "\n")

        // Calculate new cursor position
        var newCursorPos = 0
        for i in 0...lineIndex {
            newCursorPos += lines[i].count + 1
        }

        // Update text
        string = newContent
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        // Notify delegate of change
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    private func moveCurrentLineUp() {
        moveCurrentLine(direction: .up)
    }

    private func moveCurrentLineDown() {
        moveCurrentLine(direction: .down)
    }

    private func moveCurrentLine(direction: MoveDirection) {
        clearAllFolds()
        let text = string
        let cursorPos = selectedRange().location
        let lines = text.components(separatedBy: "\n")

        // Find which line the cursor is on
        var currentPos = 0
        var lineIndex = 0
        var cursorOffsetInLine = 0
        for (index, line) in lines.enumerated() {
            let lineEnd = currentPos + line.count
            if cursorPos <= lineEnd || index == lines.count - 1 {
                lineIndex = index
                cursorOffsetInLine = cursorPos - currentPos
                break
            }
            currentPos = lineEnd + 1
        }

        // Check if move is valid
        let targetIndex: Int
        switch direction {
        case .up:
            guard lineIndex > 0 else { return }
            targetIndex = lineIndex - 1
        case .down:
            guard lineIndex < lines.count - 1 else { return }
            targetIndex = lineIndex + 1
        }

        // Swap lines
        var newLines = lines
        let temp = newLines[lineIndex]
        newLines[lineIndex] = newLines[targetIndex]
        newLines[targetIndex] = temp

        let newContent = newLines.joined(separator: "\n")

        // Calculate new cursor position
        var newCursorPos = 0
        for i in 0..<targetIndex {
            newCursorPos += newLines[i].count + 1
        }
        newCursorPos += min(cursorOffsetInLine, newLines[targetIndex].count)

        // Update text
        string = newContent
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        // Notify delegate of change
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    private enum MoveDirection {
        case up
        case down
    }

    // MARK: - Sort Lines

    private func sortLines(ascending: Bool) {
        clearAllFolds()
        let text = string
        let selectedRange = self.selectedRange()

        // If there's a selection, sort only selected lines
        // Otherwise sort all lines
        if selectedRange.length > 0 {
            // Get selected text and sort it
            let nsString = text as NSString
            let selectedText = nsString.substring(with: selectedRange)
            var lines = selectedText.components(separatedBy: "\n")
            lines = ascending ? lines.sorted() : lines.sorted().reversed()
            let sortedText = lines.joined(separator: "\n")

            // Replace selected text
            if let textStorage = self.textStorage {
                textStorage.replaceCharacters(in: selectedRange, with: sortedText)
                setSelectedRange(NSRange(location: selectedRange.location, length: sortedText.count))
            }
        } else {
            // Sort all lines
            var lines = text.components(separatedBy: "\n")
            lines = ascending ? lines.sorted() : lines.sorted().reversed()
            let newContent = lines.joined(separator: "\n")

            string = newContent
            setSelectedRange(NSRange(location: 0, length: 0))
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    // MARK: - Remove Duplicate Lines

    private func removeDuplicateLines() {
        clearAllFolds()
        let text = string
        let lines = text.components(separatedBy: "\n")

        var seen = Set<String>()
        var uniqueLines: [String] = []

        for line in lines where !seen.contains(line) {
            seen.insert(line)
            uniqueLines.append(line)
        }

        let newContent = uniqueLines.joined(separator: "\n")
        string = newContent
        setSelectedRange(NSRange(location: 0, length: 0))

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    // MARK: - Change Case

    private enum CaseType {
        case uppercase
        case lowercase
        case capitalize
    }

    private func changeCase(_ caseType: CaseType) {
        let selectedRange = self.selectedRange()

        guard selectedRange.length > 0 else { return }
        clearAllFolds()

        let nsString = string as NSString
        let selectedText = nsString.substring(with: selectedRange)

        let transformedText: String
        switch caseType {
        case .uppercase:
            transformedText = selectedText.uppercased()
        case .lowercase:
            transformedText = selectedText.lowercased()
        case .capitalize:
            transformedText = selectedText.capitalized
        }

        if let textStorage = self.textStorage {
            textStorage.replaceCharacters(in: selectedRange, with: transformedText)
            setSelectedRange(NSRange(location: selectedRange.location, length: transformedText.count))
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }

    // MARK: - JSON Formatting

    private func formatJSON(minify: Bool) {
        let text = string
        let selectedRange = self.selectedRange()

        // Determine text to format (selection or entire document)
        let textToFormat: String
        let rangeToReplace: NSRange

        if selectedRange.length > 0 {
            let nsString = text as NSString
            textToFormat = nsString.substring(with: selectedRange)
            rangeToReplace = selectedRange
        } else {
            textToFormat = text
            rangeToReplace = NSRange(location: 0, length: text.count)
        }

        // Try to parse and format JSON
        guard let jsonData = textToFormat.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed)
        else {
            // Invalid JSON - beep
            NSSound.beep()
            return
        }

        let formattedData: Data?
        if minify {
            formattedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .fragmentsAllowed)
        } else {
            formattedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        }

        guard let data = formattedData,
            let formattedString = String(data: data, encoding: .utf8)
        else {
            NSSound.beep()
            return
        }

        // Replace text
        clearAllFolds()
        if let textStorage = self.textStorage {
            textStorage.replaceCharacters(in: rangeToReplace, with: formattedString)
            if selectedRange.length > 0 {
                setSelectedRange(NSRange(location: rangeToReplace.location, length: formattedString.count))
            } else {
                setSelectedRange(NSRange(location: 0, length: 0))
            }
        }

        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
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

#Preview {
    EditorView(
        text: .constant("func hello() {\n    print(\"Hello, World!\")\n}"),
        language: .swift,
        showLineNumbers: true,
        isWordWrapEnabled: true,
        fontSize: 14,
        fontName: "SF Mono"
    )
    .frame(width: 600, height: 400)
}
