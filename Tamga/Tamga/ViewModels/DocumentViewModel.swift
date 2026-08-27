import Foundation
import SwiftUI

/// ViewModel for document operations
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var isSearchVisible: Bool = false
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
              ) {
            results.append(range)
            searchStartIndex = range.upperBound
        }

        searchResults = results
        if !results.isEmpty {
            currentSearchIndex = 0
        }
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

    func replaceAll(in content: inout String) -> Int {
        guard !searchText.isEmpty else { return 0 }
        var count = 0
        while content.contains(searchText) {
            if let range = content.range(of: searchText, options: .caseInsensitive) {
                content.replaceSubrange(range, with: replaceText)
                count += 1
            }
        }
        searchResults = []
        return count
    }

    func toggleSearch() {
        isSearchVisible.toggle()
        if !isSearchVisible {
            searchText = ""
            replaceText = ""
            searchResults = []
        }
    }

    func toggleGoToLine() {
        isGoToLineVisible.toggle()
    }

    func goToLine(_ lineNumber: Int, in content: String) -> Int? {
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber >= 1 && lineNumber <= lines.count else { return nil }

        var position = 0
        for i in 0..<(lineNumber - 1) {
            position += lines[i].count + 1 // +1 for newline
        }
        targetLineNumber = lineNumber
        return position
    }

    // MARK: - Line Operations

    /// Duplicates the line at the given cursor position
    func duplicateLine(in content: String, cursorPosition: Int) -> (newContent: String, newCursorPosition: Int)? {
        let lines = content.components(separatedBy: "\n")

        // Find which line the cursor is on
        var currentPos = 0
        var lineIndex = 0
        for (index, line) in lines.enumerated() {
            let lineEnd = currentPos + line.count
            if cursorPosition <= lineEnd || index == lines.count - 1 {
                lineIndex = index
                break
            }
            currentPos = lineEnd + 1 // +1 for newline
        }

        // Duplicate the line
        var newLines = lines
        newLines.insert(lines[lineIndex], at: lineIndex + 1)

        let newContent = newLines.joined(separator: "\n")

        // Calculate new cursor position (at the start of duplicated line)
        var newCursorPos = 0
        for i in 0...lineIndex {
            newCursorPos += lines[i].count + 1
        }

        return (newContent, newCursorPos)
    }

    /// Moves the line at cursor position up or down
    func moveLine(in content: String, cursorPosition: Int, direction: MoveDirection) -> (newContent: String, newCursorPosition: Int)? {
        let lines = content.components(separatedBy: "\n")

        // Find which line the cursor is on
        var currentPos = 0
        var lineIndex = 0
        var cursorOffsetInLine = 0
        for (index, line) in lines.enumerated() {
            let lineEnd = currentPos + line.count
            if cursorPosition <= lineEnd || index == lines.count - 1 {
                lineIndex = index
                cursorOffsetInLine = cursorPosition - currentPos
                break
            }
            currentPos = lineEnd + 1
        }

        // Check if move is valid
        let targetIndex: Int
        switch direction {
        case .up:
            guard lineIndex > 0 else { return nil }
            targetIndex = lineIndex - 1
        case .down:
            guard lineIndex < lines.count - 1 else { return nil }
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

        return (newContent, newCursorPos)
    }

    enum MoveDirection {
        case up
        case down
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
    func saveFile(content: String, existingPath: URL?, suggestedName: String) async -> URL? {
        if let path = existingPath {
            do {
                try fileService.writeFile(content: content, to: path)
                return path
            } catch {
                print("Error saving file: \(error)")
                return nil
            }
        } else {
            return await saveFileAs(content: content, suggestedName: suggestedName)
        }
    }

    func saveFileAs(content: String, suggestedName: String) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text, .sourceCode, .json, .xml, .html, .plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())

        guard response == .OK, let url = panel.url else { return nil }

        do {
            try fileService.writeFile(content: content, to: url)
            return url
        } catch {
            print("Error saving file: \(error)")
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
