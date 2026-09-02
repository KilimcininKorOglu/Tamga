import AppKit
import Foundation

/// Line and text transformations triggered from the Edit menu.
///
/// Every operation clears folds first, because folding hides character ranges by index
/// and any reflow of the text would leave those indices pointing at the wrong block.
extension TamgaTextView {
    // MARK: - Sort & Transform Handlers

    @objc func handleSortLinesAscending() {
        guard window?.firstResponder === self else { return }
        sortLines(ascending: true)
    }

    @objc func handleSortLinesDescending() {
        guard window?.firstResponder === self else { return }
        sortLines(ascending: false)
    }

    @objc func handleRemoveDuplicateLines() {
        guard window?.firstResponder === self else { return }
        removeDuplicateLines()
    }

    @objc func handleUppercase() {
        guard window?.firstResponder === self else { return }
        changeCase(.uppercase)
    }

    @objc func handleLowercase() {
        guard window?.firstResponder === self else { return }
        changeCase(.lowercase)
    }

    @objc func handleCapitalize() {
        guard window?.firstResponder === self else { return }
        changeCase(.capitalize)
    }

    @objc func handleFormatJSON() {
        guard window?.firstResponder === self else { return }
        formatJSON(minify: false)
    }

    @objc func handleMinifyJSON() {
        guard window?.firstResponder === self else { return }
        formatJSON(minify: true)
    }

    @objc func handleDuplicateLine() {
        guard window?.firstResponder === self else { return }
        duplicateCurrentLine()
    }

    @objc func handleMoveLineUp() {
        guard window?.firstResponder === self else { return }
        moveCurrentLineUp()
    }

    @objc func handleMoveLineDown() {
        guard window?.firstResponder === self else { return }
        moveCurrentLineDown()
    }

    /// Applies an edit through the text view's own editing pipeline so it registers
    /// undo and notifies the delegate. Returns false when the edit is disallowed.
    @discardableResult
    func replaceCharactersUndoable(in range: NSRange, with replacement: String) -> Bool {
        guard shouldChangeText(in: range, replacementString: replacement) else { return false }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
        return true
    }

    func duplicateCurrentLine() {
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

        // Update text through the undo-aware pipeline so Cmd-Z can revert it.
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        if replaceCharactersUndoable(in: fullRange, with: newContent) {
            setSelectedRange(NSRange(location: newCursorPos, length: 0))
        }
    }

    func moveCurrentLineUp() {
        moveCurrentLine(direction: .up)
    }

    func moveCurrentLineDown() {
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

        // Update text through the undo-aware pipeline so Cmd-Z can revert it.
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        if replaceCharactersUndoable(in: fullRange, with: newContent) {
            setSelectedRange(NSRange(location: newCursorPos, length: 0))
        }
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
            if replaceCharactersUndoable(in: selectedRange, with: sortedText) {
                setSelectedRange(NSRange(location: selectedRange.location, length: (sortedText as NSString).length))
            }
        } else {
            // Sort all lines
            var lines = text.components(separatedBy: "\n")
            lines = ascending ? lines.sorted() : lines.sorted().reversed()
            let newContent = lines.joined(separator: "\n")

            let fullRange = NSRange(location: 0, length: (string as NSString).length)
            if replaceCharactersUndoable(in: fullRange, with: newContent) {
                setSelectedRange(NSRange(location: 0, length: 0))
            }
        }
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
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        if replaceCharactersUndoable(in: fullRange, with: newContent) {
            setSelectedRange(NSRange(location: 0, length: 0))
        }
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

        if replaceCharactersUndoable(in: selectedRange, with: transformedText) {
            setSelectedRange(NSRange(location: selectedRange.location, length: (transformedText as NSString).length))
        }
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
            rangeToReplace = NSRange(location: 0, length: (text as NSString).length)
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

        // Replace text through the undo-aware pipeline.
        clearAllFolds()
        if replaceCharactersUndoable(in: rangeToReplace, with: formattedString) {
            if selectedRange.length > 0 {
                setSelectedRange(NSRange(location: rangeToReplace.location, length: (formattedString as NSString).length))
            } else {
                setSelectedRange(NSRange(location: 0, length: 0))
            }
        }
    }
}
