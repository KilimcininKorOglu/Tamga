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
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        var results: [Range<String.Index>] = []
        var searchStartIndex = content.startIndex

        while searchStartIndex < content.endIndex,
            let range = content.range(
                of: searchText,
                options: .caseInsensitive,
                range: searchStartIndex..<content.endIndex
            )
        {
            results.append(range)
            searchStartIndex = range.upperBound
        }

        searchResults = results
        if !results.isEmpty {
            currentSearchIndex = 0
        }
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
        content.replaceSubrange(range, with: replaceText)
        search(in: content)
        return true
    }

    /// Replaces every match in a single forward pass.
    ///
    /// The result is built into a separate string, so a replacement that contains the
    /// search text (`foo` -> `foobar`) is never rescanned.
    func replaceAll(in content: inout String) -> Int {
        guard !searchText.isEmpty else { return 0 }

        var result = ""
        var count = 0
        var cursor = content.startIndex

        while cursor < content.endIndex,
            let range = content.range(
                of: searchText,
                options: .caseInsensitive,
                range: cursor..<content.endIndex
            )
        {
            result += content[cursor..<range.lowerBound]
            result += replaceText
            count += 1
            cursor = range.upperBound
        }

        guard count > 0 else { return 0 }

        result += content[cursor...]
        content = result
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

    func openFile() async -> (URL, String)? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return nil }

        do {
            let content = try fileService.readFile(at: url)
            return (url, content)
        } catch {
            print("Error opening file: \(error)")
            return nil
        }
    }

    /// Saves to `existingPath` when the tab is file-backed, otherwise opens the save
    /// panel. `suggestedName` is required so a never-saved tab proposes its own title
    /// instead of a generic name.
    func saveFile(content: String, existingPath: URL?, suggestedName: String, encoding: FileEncoding) async -> URL? {
        if let path = existingPath {
            do {
                try fileService.writeFile(content: content, to: path, encoding: encoding)
                return path
            } catch {
                NSAlert(error: error).runModal()
                return nil
            }
        } else {
            return await saveFileAs(content: content, suggestedName: suggestedName, encoding: encoding)
        }
    }

    func saveFileAs(content: String, suggestedName: String, encoding: FileEncoding) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return nil }

        do {
            try fileService.writeFile(content: content, to: url, encoding: encoding)
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
