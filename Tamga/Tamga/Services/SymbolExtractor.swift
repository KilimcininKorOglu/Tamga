import Foundation

/// A named location in a document shown in the outline panel.
struct DocumentSymbol: Identifiable {
    let id = UUID()
    let name: String
    /// 1-based line number, matching the gutter and the go-to-line dialog.
    let line: Int
    let kind: SymbolKind
}

/// The category of a symbol, used only to pick its icon in the outline list.
enum SymbolKind {
    case function
    case type
    case heading

    var icon: String {
        switch self {
        case .function: return "function"
        case .type: return "cube"
        case .heading: return "number"
        }
    }
}

/// Extracts an outline (functions, types, headings) from a document with per-language
/// regular expressions. This is deliberately approximate, like Notepad++'s function list:
/// it needs no parser, works for every language with a pattern, and returns an empty list
/// for the rest.
enum SymbolExtractor {
    private struct Pattern {
        let regex: NSRegularExpression
        let kind: SymbolKind
        let group: Int
    }

    /// Names that a loose C-family function pattern would wrongly capture from a control
    /// statement; they are dropped from the result.
    private static let excludedNames: Set<String> = [
        "if", "for", "while", "switch", "catch", "return", "else", "do"
    ]

    static func symbols(in content: String, language: SyntaxLanguage) -> [DocumentSymbol] {
        guard let patterns = patternTable[language] else { return [] }

        var result: [DocumentSymbol] = []
        let lines = content.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if let symbol = firstSymbol(in: line, at: index + 1, patterns: patterns) {
                result.append(symbol)
            }
        }
        return result
    }

    /// Returns the symbol for the first pattern that matches the line, or nil.
    private static func firstSymbol(in line: String, at lineNumber: Int, patterns: [Pattern]) -> DocumentSymbol? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        for pattern in patterns {
            guard let match = pattern.regex.firstMatch(in: line, range: fullRange),
                match.numberOfRanges > pattern.group
            else { continue }
            let nameRange = match.range(at: pattern.group)
            guard nameRange.location != NSNotFound else { continue }

            let name = nsLine.substring(with: nameRange)
            guard !excludedNames.contains(name) else { continue }
            return DocumentSymbol(name: name, line: lineNumber, kind: pattern.kind)
        }
        return nil
    }

    // MARK: - Pattern table

    private static let patternTable: [SyntaxLanguage: [Pattern]] = compile(rawPatterns)

    private static func compile(
        _ raw: [SyntaxLanguage: [(pattern: String, kind: SymbolKind, group: Int)]]
    ) -> [SyntaxLanguage: [Pattern]] {
        var table: [SyntaxLanguage: [Pattern]] = [:]
        for (language, specs) in raw {
            let patterns = specs.compactMap { spec -> Pattern? in
                guard let regex = try? NSRegularExpression(pattern: spec.pattern) else { return nil }
                return Pattern(regex: regex, kind: spec.kind, group: spec.group)
            }
            if !patterns.isEmpty {
                table[language] = patterns
            }
        }
        return table
    }

    /// Per-language declaration patterns. Each captures the symbol name in `group`. The
    /// first pattern that matches a line wins, so order type patterns before the looser
    /// function ones where they could overlap.
    private static let rawPatterns: [SyntaxLanguage: [(pattern: String, kind: SymbolKind, group: Int)]] = [
        .swift: [
            ("^\\s*(?:public |private |internal |fileprivate |open |final |static |class )*(?:class|struct|enum|protocol|extension|actor)\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^\\s*(?:public |private |internal |fileprivate |open |final |static |override |mutating )*func\\s+([A-Za-z_][A-Za-z0-9_]*)", .function, 1)
        ],
        .python: [
            ("^\\s*class\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^\\s*(?:async\\s+)?def\\s+([A-Za-z_][A-Za-z0-9_]*)", .function, 1)
        ],
        .javascript: [
            ("^\\s*(?:export\\s+)?(?:default\\s+)?class\\s+([A-Za-z_$][A-Za-z0-9_$]*)", .type, 1),
            ("^\\s*(?:export\\s+)?(?:async\\s+)?function\\s*\\*?\\s*([A-Za-z_$][A-Za-z0-9_$]*)", .function, 1),
            ("^\\s*(?:export\\s+)?(?:const|let|var)\\s+([A-Za-z_$][A-Za-z0-9_$]*)\\s*=\\s*(?:async\\s*)?\\([^)]*\\)\\s*=>", .function, 1)
        ],
        .php: [
            ("^\\s*(?:abstract |final )*(?:class|interface|trait|enum)\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^\\s*(?:public |private |protected |static |abstract |final )*function\\s+([A-Za-z_][A-Za-z0-9_]*)", .function, 1)
        ],
        .go: [
            ("^\\s*type\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^\\s*func\\s+(?:\\([^)]*\\)\\s*)?([A-Za-z_][A-Za-z0-9_]*)", .function, 1)
        ],
        .rust: [
            ("^\\s*(?:pub\\s+)?(?:struct|enum|trait|type|impl)\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^\\s*(?:pub\\s+)?(?:async\\s+)?(?:unsafe\\s+)?fn\\s+([A-Za-z_][A-Za-z0-9_]*)", .function, 1)
        ],
        .c: [
            ("^\\s*(?:struct|enum|union)\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^[A-Za-z_][A-Za-z0-9_ \\t\\*]*\\s+\\*?([A-Za-z_][A-Za-z0-9_]*)\\s*\\([^;{]*\\)\\s*\\{?\\s*$", .function, 1)
        ],
        .cpp: [
            ("^\\s*(?:class|struct|enum|union|namespace)\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^[A-Za-z_][A-Za-z0-9_ \\t\\*:<>]*\\s+\\*?([A-Za-z_][A-Za-z0-9_]*)\\s*\\([^;{]*\\)\\s*\\{?\\s*$", .function, 1)
        ],
        .java: [
            ("^\\s*(?:public |private |protected |static |final |abstract )*(?:class|interface|enum)\\s+([A-Za-z_][A-Za-z0-9_]*)", .type, 1),
            ("^\\s*(?:public |private |protected |static |final |abstract |synchronized )*(?:[A-Za-z_][A-Za-z0-9_<>\\[\\]]*\\s+)([A-Za-z_][A-Za-z0-9_]*)\\s*\\([^;{]*\\)\\s*\\{?\\s*$", .function, 1)
        ],
        .markdown: [
            ("^#{1,6}\\s+(.+?)\\s*#*\\s*$", .heading, 1)
        ]
    ]
}
