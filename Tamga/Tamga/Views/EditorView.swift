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
