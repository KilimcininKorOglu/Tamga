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

/// Line ending styles a document can use on disk.
///
/// The editor always holds content with `\n` separators, because splitting `\r\n`
/// on `CharacterSet.newlines` would double the line count in the gutter. The chosen
/// style is applied only when the file is written.
enum LineEnding: String, Codable, CaseIterable {
    case lf = "LF"
    case crlf = "CRLF"
    case cr = "CR"

    /// The byte sequence written to disk for this style.
    var sequence: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    var displayName: String { rawValue }

    /// Detects the dominant style. `CRLF` wins when any `\r\n` is present, then a lone
    /// `\r` means `CR`, otherwise `LF`.
    static func detect(from text: String) -> LineEnding {
        if text.contains("\r\n") { return .crlf }
        if text.contains("\r") { return .cr }
        return .lf
    }
}

/// File encoding options. Raw values double as the status-bar labels, so the selector
/// lists exactly the encodings the app can write.
enum FileEncoding: String, CaseIterable {
    case utf8 = "UTF-8"
    case utf16 = "UTF-16"
    case utf16LE = "UTF-16 LE"
    case utf16BE = "UTF-16 BE"
    case ascii = "ASCII"
    case isoLatin1 = "ISO-8859-1"
    case isoLatin2 = "ISO-8859-2"
    case windows1252 = "Windows-1252"
    case windows1250 = "Windows-1250"
    case shiftJIS = "Shift JIS"
    case eucJP = "EUC-JP"
    case gb18030 = "GB18030"
    case big5 = "Big5"

    /// A `CFStringEncodings` value bridged into a `String.Encoding`, for encodings with
    /// no direct `String.Encoding` constant.
    private static func cf(_ value: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(value.rawValue)))
    }

    /// Static map instead of a `switch`, to stay under the complexity limit as the list grows.
    private static let encodings: [FileEncoding: String.Encoding] = [
        .utf8: .utf8,
        .utf16: .utf16,
        .utf16LE: .utf16LittleEndian,
        .utf16BE: .utf16BigEndian,
        .ascii: .ascii,
        .isoLatin1: .isoLatin1,
        .isoLatin2: .isoLatin2,
        .windows1252: .windowsCP1252,
        .windows1250: .windowsCP1250,
        .shiftJIS: .shiftJIS,
        .eucJP: .japaneseEUC,
        .gb18030: cf(.GB_18030_2000),
        .big5: cf(.big5)
    ]

    var encoding: String.Encoding {
        Self.encodings[self] ?? .utf8
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
