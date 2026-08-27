import Foundation

/// Represents document metadata and statistics
struct DocumentInfo {
    var characterCount: Int
    var wordCount: Int
    var lineCount: Int
    var currentLine: Int
    var currentColumn: Int

    init(content: String = "", cursorPosition: Int = 0) {
        self.characterCount = content.count
        self.wordCount = DocumentInfo.countWords(in: content)
        self.lineCount = DocumentInfo.countLines(in: content)

        let (line, column) = DocumentInfo.calculateLineColumn(
            content: content,
            position: cursorPosition
        )
        self.currentLine = line
        self.currentColumn = column
    }

    private static func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

    private static func countLines(in text: String) -> Int {
        if text.isEmpty { return 1 }
        return text.components(separatedBy: .newlines).count
    }

    /// Line and column for a caret offset.
    ///
    /// Works in UTF-16 units because the offset comes from `NSTextView.selectedRange`,
    /// which counts the same way; using Character offsets would drift on emoji.
    private static func calculateLineColumn(content: String, position: Int) -> (line: Int, column: Int) {
        let text = content as NSString
        guard text.length > 0, position > 0 else {
            return (1, 1)
        }

        let safePosition = min(position, text.length)
        let prefix = text.substring(to: safePosition)
        let lines = prefix.components(separatedBy: .newlines)

        let line = lines.count
        let column = (lines.last.map { ($0 as NSString).length } ?? 0) + 1

        return (line, column)
    }
}

/// File encoding options
enum FileEncoding: String, CaseIterable {
    case utf8 = "UTF-8"
    case utf16 = "UTF-16"
    case ascii = "ASCII"
    case isoLatin1 = "ISO-8859-1"

    var encoding: String.Encoding {
        switch self {
        case .utf8: return .utf8
        case .utf16: return .utf16
        case .ascii: return .ascii
        case .isoLatin1: return .isoLatin1
        }
    }

    static func detect(from data: Data) -> FileEncoding {
        // Check for BOM (Byte Order Mark)
        if data.count >= 3 {
            let bom = Array(data.prefix(3))
            if bom == [0xEF, 0xBB, 0xBF] {
                return .utf8
            }
        }

        if data.count >= 2 {
            let bom = Array(data.prefix(2))
            if bom == [0xFE, 0xFF] || bom == [0xFF, 0xFE] {
                return .utf16
            }
        }

        // Try UTF-8 first
        if String(data: data, encoding: .utf8) != nil {
            return .utf8
        }

        // Try other encodings
        if String(data: data, encoding: .isoLatin1) != nil {
            return .isoLatin1
        }

        return .utf8
    }
}
