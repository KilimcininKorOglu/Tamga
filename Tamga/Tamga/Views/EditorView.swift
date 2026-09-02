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
    var searchMatches: [NSRange] = []
    var currentMatchIndex: Int = 0
    var onCursorPositionChange: (Int) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
            searchMatches: searchMatches,
            currentMatchIndex: currentMatchIndex,
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
    let searchMatches: [NSRange]
    let currentMatchIndex: Int
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

        // Line numbers: a plain left-pinned overlay driven by the layout manager, so a
        // soft-wrapped line keeps one number aligned with its first visual row.
        let gutter = GutterView(textView: textView, scrollView: scrollView)
        scrollView.addSubview(gutter)
        context.coordinator.gutterView = gutter
        context.coordinator.updateGutterAppearance(fontSize: fontSize, isDarkMode: isDarkMode)
        context.coordinator.applyGutter(visible: showLineNumbers)

        // Redraw the gutter and keep it pinned as the text scrolls or the view resizes.
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.contentView.postsFrameChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
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
        context.coordinator.updateGutterAppearance(fontSize: fontSize, isDarkMode: isDarkMode)
        context.coordinator.applyGutter(visible: showLineNumbers)

        // Apply syntax highlighting
        context.coordinator.applySyntaxHighlighting(language: language, isDarkMode: isDarkMode)

        // Handle go to position
        if let position = goToPosition, position != context.coordinator.lastGoToPosition {
            context.coordinator.lastGoToPosition = position
            context.coordinator.scrollToPosition(position)
        }

        // Paint search-match backgrounds on top and select the current match.
        context.coordinator.applySearchHighlights(
            matches: searchMatches,
            current: currentMatchIndex,
            isDarkMode: isDarkMode
        )
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
        weak var gutterView: GutterView?
        var lastGoToPosition: Int?
        private var lastAppliedMatchCurrent = -1

        private let highlighter = SyntaxHighlighter.shared
        private let treeSitterController = TreeSitterHighlightController()
        private var isUpdating = false
        private var gutterVisible = true

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func scrollToPosition(_ position: Int) {
            guard let textView = textView else { return }
            let safePosition = min(position, (textView.string as NSString).length)
            let range = NSRange(location: safePosition, length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView, !isUpdating else { return }
            parent.text = textView.string
            layoutGutter()
            applySyntaxHighlighting(language: parent.language, isDarkMode: parent.isDarkMode)
        }

        /// Reports the caret offset so the status bar can show line and column.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.onCursorPositionChange(textView.selectedRange().location)
        }

        // MARK: - Gutter

        /// Shows or hides the gutter and reserves the matching left inset for the text.
        func applyGutter(visible: Bool) {
            gutterVisible = visible
            gutterView?.isHidden = !visible
            layoutGutter()
        }

        func updateGutterAppearance(fontSize: CGFloat, isDarkMode: Bool) {
            guard let gutterView else { return }
            gutterView.numberFont = .monospacedSystemFont(ofSize: max(fontSize - 2, 9), weight: .regular)
            gutterView.numberColor =
                isDarkMode
                ? NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1)
                : NSColor.secondaryLabelColor
            gutterView.gutterColor =
                isDarkMode
                ? NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
                : NSColor.controlBackgroundColor
            layoutGutter()
        }

        /// Pins the gutter to the left of the clip view and insets the text past it.
        private func layoutGutter() {
            guard let textView = textView, let scrollView = scrollView, let gutterView else { return }
            let width = gutterVisible ? gutterView.width(forLineCount: currentLineCount()) : 0

            let clip = scrollView.contentView.frame
            gutterView.frame = NSRect(x: clip.minX, y: clip.minY, width: width, height: clip.height)

            let inset = gutterVisible ? width + 4 : 8
            if abs(textView.textContainerInset.width - inset) > 0.5 {
                textView.textContainerInset = NSSize(width: inset, height: 8)
            }
            gutterView.needsDisplay = true
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

            // Regex fallback for non-migrated languages. Apply the colors as attributes
            // on the existing text storage instead of replacing it, so the text, the undo
            // stack, the selection, and the editor font all stay intact.
            guard let textStorage = textView.textStorage, !textView.string.isEmpty else { return }

            isUpdating = true
            defer { isUpdating = false }

            let highlighted = highlighter.highlight(
                text: textView.string,
                language: language,
                isDarkMode: isDarkMode
            )

            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.beginEditing()
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            highlighted.enumerateAttribute(
                .foregroundColor,
                in: NSRange(location: 0, length: highlighted.length)
            ) { value, range, _ in
                if let color = value as? NSColor {
                    textStorage.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
            textStorage.endEditing()
        }

        /// Paints a background behind every search match (stronger for the current one)
        /// via layout-manager temporary attributes, so it layers over both highlighting
        /// engines without touching text storage. Selects and scrolls to the current match
        /// only when the index changes, so typing in the editor does not hijack the caret.
        func applySearchHighlights(matches: [NSRange], current: Int, isDarkMode: Bool) {
            guard let textView = textView, let layoutManager = textView.layoutManager else { return }

            let length = (textView.string as NSString).length
            layoutManager.removeTemporaryAttribute(
                .backgroundColor,
                forCharacterRange: NSRange(location: 0, length: length)
            )

            let matchColor = NSColor.systemYellow.withAlphaComponent(isDarkMode ? 0.35 : 0.5)
            let currentColor = NSColor.systemOrange.withAlphaComponent(isDarkMode ? 0.55 : 0.6)

            for (index, range) in matches.enumerated() where NSMaxRange(range) <= length {
                layoutManager.addTemporaryAttribute(
                    .backgroundColor,
                    value: index == current ? currentColor : matchColor,
                    forCharacterRange: range
                )
            }

            guard !matches.isEmpty else {
                lastAppliedMatchCurrent = -1
                return
            }

            // Only move the selection on an index change (find navigation or panel open).
            guard current != lastAppliedMatchCurrent else { return }
            lastAppliedMatchCurrent = current

            guard current >= 0, current < matches.count else { return }
            let currentRange = matches[current]
            guard NSMaxRange(currentRange) <= length else { return }
            textView.setSelectedRange(currentRange)
            textView.scrollRangeToVisible(currentRange)
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            layoutGutter()
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
