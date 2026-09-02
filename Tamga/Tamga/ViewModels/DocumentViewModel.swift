import Foundation
import SwiftUI

/// ViewModel for document operations
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var isSearchVisible: Bool = false
    /// Whether the replace row of the find panel is expanded.
    @Published var isReplaceVisible: Bool = false
    /// Treat `searchText` as an `NSRegularExpression` pattern.
    @Published var isRegexEnabled: Bool = false
    /// Match case exactly instead of the default case-insensitive scan.
    @Published var isCaseSensitive: Bool = false
    /// Match whole words only (ignored in regex mode, where the pattern owns its boundaries).
    @Published var isWholeWord: Bool = false
    /// True when a regex pattern fails to compile, so the panel can flag it.
    @Published var isSearchInvalid: Bool = false
    @Published var searchResults: [Range<String.Index>] = []
    @Published var currentSearchIndex: Int = 0
    @Published var isGoToLineVisible: Bool = false
    @Published var targetLineNumber: Int?
    @Published var isCompareVisible: Bool = false
    @Published var compareText: String = ""
    @Published var compareTitle: String = ""

    private let fileService = FileService.shared

    // MARK: - Search Operations

    func search(in content: String) {
        searchResults = computeMatches(in: content)
        currentSearchIndex = 0
    }

    /// Finds every match with the current toggles, through one `NSRegularExpression`.
    /// Non-regex terms are escaped first, so a literal search never triggers pattern
    /// syntax. Returns an empty list and sets `isSearchInvalid` when a regex fails to
    /// compile, so a half-typed pattern never throws.
    private func computeMatches(in content: String) -> [Range<String.Index>] {
        guard !searchText.isEmpty else {
            isSearchInvalid = false
            return []
        }
        guard let regex = makeSearchRegex() else {
            isSearchInvalid = true
            return []
        }
        isSearchInvalid = false
        let fullRange = NSRange(content.startIndex..., in: content)
        return regex.matches(in: content, options: [], range: fullRange)
            .compactMap { Range($0.range, in: content) }
    }

    /// Builds the matcher from the toggles. Escapes the term unless regex mode is on,
    /// and wraps it in `\b` word boundaries for a whole-word literal search.
    private func makeSearchRegex() -> NSRegularExpression? {
        var pattern = isRegexEnabled ? searchText : NSRegularExpression.escapedPattern(for: searchText)
        if isWholeWord && !isRegexEnabled {
            pattern = "\\b\(pattern)\\b"
        }
        let options: NSRegularExpression.Options = isCaseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    /// Current matches as UTF-16 `NSRange`s for the editor to select and highlight.
    /// `searchResults` indexes into the same `content`, so the conversion stays valid.
    func matchRanges(in content: String) -> [NSRange] {
        searchResults.map { NSRange($0, in: content) }
    }

    func findNext() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
    }

    func findPrevious() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
    }

    func replace(in content: inout String) -> Bool {
        guard currentSearchIndex < searchResults.count else { return false }
        let range = searchResults[currentSearchIndex]
        content.replaceSubrange(range, with: expandedReplacement(for: range, in: content))
        search(in: content)
        return true
    }

    /// Replacement text for a single match. Expands `$1`-style templates against the
    /// capture groups in regex mode; returns the literal replace text otherwise.
    private func expandedReplacement(for range: Range<String.Index>, in content: String) -> String {
        guard isRegexEnabled, let regex = makeSearchRegex() else { return replaceText }
        let target = NSRange(range, in: content)
        let fullRange = NSRange(content.startIndex..., in: content)
        guard let match = regex.matches(in: content, options: [], range: fullRange)
            .first(where: { $0.range == target })
        else {
            return replaceText
        }
        return regex.replacementString(for: match, in: content, offset: 0, template: replaceText)
    }

    /// Replaces every match in a single pass. Regex mode honors `$1` templates; a literal
    /// search escapes the replacement so `$` and `\` stay verbatim.
    func replaceAll(in content: inout String) -> Int {
        guard !searchText.isEmpty, let regex = makeSearchRegex() else { return 0 }

        let mutable = NSMutableString(string: content)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let template = isRegexEnabled ? replaceText : NSRegularExpression.escapedTemplate(for: replaceText)
        let count = regex.replaceMatches(in: mutable, options: [], range: fullRange, withTemplate: template)

        guard count > 0 else { return 0 }

        content = mutable as String
        searchResults = []
        return count
    }

    func toggleSearch() {
        isSearchVisible.toggle()
        if !isSearchVisible {
            closeSearch()
        }
    }

    /// Opens the find panel with the replace row already expanded.
    func showReplace() {
        isReplaceVisible = true
        isSearchVisible = true
    }

    private func closeSearch() {
        searchText = ""
        replaceText = ""
        searchResults = []
        isReplaceVisible = false
        isSearchInvalid = false
    }

    func toggleGoToLine() {
        isGoToLineVisible.toggle()
    }

    func goToLine(_ lineNumber: Int, in content: String) -> Int? {
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber >= 1 && lineNumber <= lines.count else { return nil }

        var position = 0
        for i in 0..<(lineNumber - 1) {
            position += (lines[i] as NSString).length + 1  // +1 for newline; UTF-16 units for the caret
        }
        targetLineNumber = lineNumber
        return position
    }

    // MARK: - File Operations

    func openFile() async -> (url: URL, content: String, lineEnding: LineEnding)? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return nil }

        do {
            let (content, lineEnding) = try fileService.readFileWithLineEnding(at: url)
            return (url, content, lineEnding)
        } catch {
            print("Error opening file: \(error)")
            return nil
        }
    }

    /// Saves to `existingPath` when the tab is file-backed, otherwise opens the save
    /// panel. `suggestedName` is required so a never-saved tab proposes its own title
    /// instead of a generic name.
    func saveFile(
        content: String,
        existingPath: URL?,
        suggestedName: String,
        encoding: FileEncoding,
        lineEnding: LineEnding
    ) async -> URL? {
        if let path = existingPath {
            do {
                try fileService.writeFile(content: content, to: path, encoding: encoding, lineEnding: lineEnding)
                return path
            } catch {
                NSAlert(error: error).runModal()
                return nil
            }
        } else {
            return await saveFileAs(content: content, suggestedName: suggestedName, encoding: encoding, lineEnding: lineEnding)
        }
    }

    func saveFileAs(content: String, suggestedName: String, encoding: FileEncoding, lineEnding: LineEnding) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return nil }

        do {
            try fileService.writeFile(content: content, to: url, encoding: encoding, lineEnding: lineEnding)
            return url
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    // MARK: - Compare Operations

    func openFileForCompare() async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]
        panel.message = String(localized: "compare.with.file")

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return }

        do {
            let content = try fileService.readFile(at: url)
            compareText = content
            compareTitle = url.lastPathComponent
            isCompareVisible = true
        } catch {
            print("Error opening file for compare: \(error)")
        }
    }

    func closeCompare() {
        isCompareVisible = false
        compareText = ""
        compareTitle = ""
    }
}
