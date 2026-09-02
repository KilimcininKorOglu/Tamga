// swiftlint:disable line_length
// The keyword alternations below are single regex literals; splitting them would
// break the pattern rather than improve it.

import AppKit
import Foundation
import SwiftUI

/// Service for syntax highlighting code
class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()

    private init() {}

    // MARK: - Theme Colors

    struct Theme {
        let keyword: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        let function: NSColor
        let type: NSColor
        let variable: NSColor
        let `operator`: NSColor
        let attribute: NSColor
        let tag: NSColor
        let background: NSColor
        let foreground: NSColor

        static var light: Theme {
            Theme(
                keyword: NSColor(red: 0.61, green: 0.12, blue: 0.69, alpha: 1),
                string: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1),
                comment: NSColor(red: 0.42, green: 0.47, blue: 0.51, alpha: 1),
                number: NSColor(red: 0.11, green: 0.43, blue: 0.69, alpha: 1),
                function: NSColor(red: 0.16, green: 0.50, blue: 0.73, alpha: 1),
                type: NSColor(red: 0.00, green: 0.55, blue: 0.55, alpha: 1),
                variable: NSColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1),
                operator: NSColor(red: 0.61, green: 0.12, blue: 0.69, alpha: 1),
                attribute: NSColor(red: 0.61, green: 0.12, blue: 0.69, alpha: 1),
                tag: NSColor(red: 0.13, green: 0.39, blue: 0.63, alpha: 1),
                background: NSColor.white,
                foreground: NSColor.black
            )
        }

        static var dark: Theme {
            Theme(
                keyword: NSColor(red: 0.99, green: 0.47, blue: 0.53, alpha: 1),
                string: NSColor(red: 0.99, green: 0.81, blue: 0.51, alpha: 1),
                comment: NSColor(red: 0.49, green: 0.55, blue: 0.60, alpha: 1),
                number: NSColor(red: 0.71, green: 0.84, blue: 0.99, alpha: 1),
                function: NSColor(red: 0.51, green: 0.68, blue: 0.99, alpha: 1),
                type: NSColor(red: 0.51, green: 0.87, blue: 0.85, alpha: 1),
                variable: NSColor(red: 0.87, green: 0.89, blue: 0.91, alpha: 1),
                operator: NSColor(red: 0.99, green: 0.47, blue: 0.53, alpha: 1),
                attribute: NSColor(red: 0.99, green: 0.47, blue: 0.53, alpha: 1),
                tag: NSColor(red: 0.51, green: 0.68, blue: 0.99, alpha: 1),
                background: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1),
                foreground: NSColor.white
            )
        }
    }

    // MARK: - Highlighting

    func highlight(text: String, language: SyntaxLanguage, isDarkMode: Bool) -> NSAttributedString {
        let theme = isDarkMode ? Theme.dark : Theme.light
        let attributedString = NSMutableAttributedString(string: text)

        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        attributedString.addAttribute(.foregroundColor, value: theme.foreground, range: fullRange)
        attributedString.addAttribute(.font, value: font, range: fullRange)

        guard language != .plainText else {
            return attributedString
        }

        let patterns = getPatterns(for: language)

        for (pattern, color) in patterns {
            applyPattern(pattern, color: color(theme), to: attributedString, in: text)
        }

        return attributedString
    }

    private func applyPattern(_ pattern: String, color: NSColor, to attributedString: NSMutableAttributedString, in text: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return
        }

        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: fullRange)

        for match in matches {
            attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }

    // MARK: - Language Patterns

    /// Pattern set per language. `plainText` is absent on purpose: it has no patterns.
    /// Add an entry here when adding a `SyntaxLanguage` case to the regex path.
    private static let patternKeyPaths: [SyntaxLanguage: KeyPath<SyntaxHighlighter, [(String, (Theme) -> NSColor)]>] = [
        .swift: \.swiftPatterns,
        .python: \.pythonPatterns,
        .javascript: \.javascriptPatterns,
        .php: \.phpPatterns,
        .json: \.jsonPatterns,
        .html: \.htmlPatterns,
        .css: \.cssPatterns,
        .markdown: \.markdownPatterns,
        .xml: \.xmlPatterns,
        .sql: \.sqlPatterns,
        .shell: \.shellPatterns,
        .yaml: \.yamlPatterns,
        .toml: \.tomlPatterns
    ]

    private func getPatterns(for language: SyntaxLanguage) -> [(String, (Theme) -> NSColor)] {
        guard let keyPath = Self.patternKeyPaths[language] else { return [] }
        return self[keyPath: keyPath]
    }

    // MARK: - Swift Patterns

    private var swiftPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"//.*$"#, { $0.comment }),
            (#"/\*[\s\S]*?\*/"#, { $0.comment }),

            // Strings
            (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, { $0.string }),
            (#"\"\"\"[\s\S]*?\"\"\""#, { $0.string }),

            // Keywords
            (
                #"\b(func|var|let|if|else|guard|switch|case|default|for|while|repeat|return|break|continue|import|class|struct|enum|protocol|extension|init|deinit|self|Self|super|true|false|nil|throws|throw|try|catch|async|await|actor|some|any|where|typealias|associatedtype|inout|static|final|override|private|public|internal|fileprivate|open|lazy|weak|unowned|mutating|nonmutating|convenience|required|optional|dynamic|indirect|precedencegroup|infix|prefix|postfix|operator|subscript|get|set|willSet|didSet|is|as|in)\b"#,
                { $0.keyword }
            ),

            // Types
            (#"\b[A-Z][a-zA-Z0-9_]*\b"#, { $0.type }),

            // Numbers
            (#"\b\d+\.?\d*\b"#, { $0.number }),

            // Attributes
            (#"@[a-zA-Z_][a-zA-Z0-9_]*"#, { $0.attribute })
        ]
    }

    // MARK: - Python Patterns

    private var pythonPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"#.*$"#, { $0.comment }),
            (#"\"\"\"[\s\S]*?\"\"\""#, { $0.string }),
            (#"'''[\s\S]*?'''"#, { $0.string }),

            // Strings
            (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, { $0.string }),
            (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, { $0.string }),

            // Keywords
            (
                #"\b(and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|True|False|None)\b"#,
                { $0.keyword }
            ),

            // Numbers
            (#"\b\d+\.?\d*\b"#, { $0.number }),

            // Decorators
            (#"@[a-zA-Z_][a-zA-Z0-9_]*"#, { $0.attribute })
        ]
    }

    // MARK: - JavaScript Patterns

    private var javascriptPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"//.*$"#, { $0.comment }),
            (#"/\*[\s\S]*?\*/"#, { $0.comment }),

            // Strings
            (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, { $0.string }),
            (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, { $0.string }),
            (#"`[^`]*`"#, { $0.string }),

            // Keywords
            (
                #"\b(break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|function|if|import|in|instanceof|let|new|return|super|switch|this|throw|try|typeof|var|void|while|with|yield|async|await|of|true|false|null|undefined)\b"#,
                { $0.keyword }
            ),

            // Numbers
            (#"\b\d+\.?\d*\b"#, { $0.number })
        ]
    }

    // MARK: - PHP Patterns

    private var phpPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"//.*$"#, { $0.comment }),
            (#"#.*$"#, { $0.comment }),
            (#"/\*[\s\S]*?\*/"#, { $0.comment }),

            // PHP tags
            (#"<\?php|\?>|<\?=?"#, { $0.keyword }),

            // Strings
            (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, { $0.string }),
            (#"'[^'\\]*(?:\\.[^'\\]*)*'"#, { $0.string }),
            (#"<<<['\""]?(\w+)['\""]?[\s\S]*?\1"#, { $0.string }),

            // Variables
            (#"\$[a-zA-Z_][a-zA-Z0-9_]*"#, { $0.variable }),

            // Keywords
            (
                #"\b(abstract|and|array|as|break|callable|case|catch|class|clone|const|continue|declare|default|die|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|eval|exit|extends|final|finally|fn|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|match|namespace|new|or|print|private|protected|public|readonly|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield|yield from|true|false|null|self|parent|__CLASS__|__DIR__|__FILE__|__FUNCTION__|__LINE__|__METHOD__|__NAMESPACE__|__TRAIT__)\b"#,
                { $0.keyword }
            ),

            // Types
            (#"\b(int|float|bool|string|array|object|callable|iterable|void|mixed|never|null)\b"#, { $0.type }),

            // Numbers
            (#"\b\d+\.?\d*\b"#, { $0.number }),

            // Functions
            (#"\b[a-zA-Z_][a-zA-Z0-9_]*\s*\("#, { $0.function })
        ]
    }

    // MARK: - JSON Patterns

    private var jsonPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Keys
            (#"\"[^\"]+\"\s*:"#, { $0.keyword }),

            // Strings
            (#":\s*\"[^\"]*\""#, { $0.string }),

            // Numbers
            (#":\s*-?\d+\.?\d*"#, { $0.number }),

            // Booleans and null
            (#"\b(true|false|null)\b"#, { $0.keyword })
        ]
    }

    // MARK: - HTML Patterns

    private var htmlPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"<!--[\s\S]*?-->"#, { $0.comment }),

            // Tags
            (#"</?[a-zA-Z][a-zA-Z0-9]*"#, { $0.tag }),
            (#"/?>|<"#, { $0.tag }),

            // Attributes
            (#"\s[a-zA-Z-]+="#, { $0.attribute }),

            // Strings
            (#"\"[^\"]*\""#, { $0.string }),
            (#"'[^']*'"#, { $0.string })
        ]
    }

    // MARK: - CSS Patterns

    private var cssPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"/\*[\s\S]*?\*/"#, { $0.comment }),

            // Selectors
            (#"[.#]?[a-zA-Z][a-zA-Z0-9_-]*\s*\{"#, { $0.keyword }),

            // Properties
            (#"[a-zA-Z-]+\s*:"#, { $0.attribute }),

            // Values
            (#":\s*[^;{}]+"#, { $0.string }),

            // Numbers with units
            (#"\d+\.?\d*(px|em|rem|%|vh|vw|pt|cm|mm|in)?"#, { $0.number }),

            // Colors
            (#"#[a-fA-F0-9]{3,8}\b"#, { $0.number })
        ]
    }

    // MARK: - Markdown Patterns

    private var markdownPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Headers
            (#"^#{1,6}\s.*$"#, { $0.keyword }),

            // Bold
            (#"\*\*[^*]+\*\*"#, { $0.keyword }),
            (#"__[^_]+__"#, { $0.keyword }),

            // Italic
            (#"\*[^*]+\*"#, { $0.string }),
            (#"_[^_]+_"#, { $0.string }),

            // Code
            (#"`[^`]+`"#, { $0.function }),
            (#"```[\s\S]*?```"#, { $0.function }),

            // Links
            (#"\[([^\]]+)\]\(([^)]+)\)"#, { $0.attribute }),

            // Lists
            (#"^[\s]*[-*+]\s"#, { $0.keyword }),
            (#"^\s*\d+\.\s"#, { $0.keyword })
        ]
    }

    // MARK: - XML Patterns

    private var xmlPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"<!--[\s\S]*?-->"#, { $0.comment }),

            // Tags
            (#"</?[a-zA-Z][a-zA-Z0-9:_-]*"#, { $0.tag }),
            (#"/?>|<"#, { $0.tag }),

            // Attributes
            (#"\s[a-zA-Z:_][a-zA-Z0-9:_-]*="#, { $0.attribute }),

            // Strings
            (#"\"[^\"]*\""#, { $0.string }),
            (#"'[^']*'"#, { $0.string }),

            // CDATA
            (#"<!\[CDATA\[[\s\S]*?\]\]>"#, { $0.comment })
        ]
    }

    // MARK: - SQL Patterns

    private var sqlPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"--.*$"#, { $0.comment }),
            (#"/\*[\s\S]*?\*/"#, { $0.comment }),

            // Strings
            (#"'[^']*'"#, { $0.string }),

            // Keywords (case-insensitive: SQL keywords are not case-sensitive)
            (
                #"(?i)\b(SELECT|FROM|WHERE|AND|OR|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|INDEX|VIEW|DROP|ALTER|ADD|COLUMN|PRIMARY|KEY|FOREIGN|REFERENCES|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|NULL|NOT|IN|LIKE|BETWEEN|EXISTS|CASE|WHEN|THEN|ELSE|END|COUNT|SUM|AVG|MIN|MAX)\b"#,
                { $0.keyword }
            ),

            // Numbers
            (#"\b\d+\.?\d*\b"#, { $0.number })
        ]
    }

    // MARK: - Shell Patterns

    private var shellPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"#.*$"#, { $0.comment }),

            // Strings
            (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, { $0.string }),
            (#"'[^']*'"#, { $0.string }),

            // Keywords
            (
                #"\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|exit|local|export|source|alias|unalias|cd|pwd|echo|printf|read|test|true|false)\b"#,
                { $0.keyword }
            ),

            // Variables
            (#"\$[a-zA-Z_][a-zA-Z0-9_]*"#, { $0.variable }),
            (#"\$\{[^}]+\}"#, { $0.variable }),

            // Numbers
            (#"\b\d+\b"#, { $0.number })
        ]
    }

    // MARK: - YAML Patterns

    private var yamlPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"#.*$"#, { $0.comment }),

            // Keys
            (#"^[a-zA-Z_][a-zA-Z0-9_]*:"#, { $0.keyword }),
            (#"^\s+[a-zA-Z_][a-zA-Z0-9_]*:"#, { $0.keyword }),

            // Strings
            (#"\"[^\"]*\""#, { $0.string }),
            (#"'[^']*'"#, { $0.string }),

            // Booleans and null
            (#"\b(true|false|yes|no|null|~)\b"#, { $0.keyword }),

            // Numbers
            (#"\b\d+\.?\d*\b"#, { $0.number })
        ]
    }

    // MARK: - TOML / INI Patterns

    /// Shared by TOML and INI-style config files (`.toml`, `.ini`, `.conf`, `.cfg`, `.env`).
    private var tomlPatterns: [(String, (Theme) -> NSColor)] {
        [
            // Comments
            (#"#.*$"#, { $0.comment }),
            (#";.*$"#, { $0.comment }),

            // Section headers, e.g. [server] or [tool.poetry]
            (#"^\s*\[.*\]"#, { $0.keyword }),

            // Keys before an '=' or ':'
            (#"^\s*[A-Za-z0-9_.\-]+\s*(?=[:=])"#, { $0.attribute }),

            // Strings
            (#"\"[^\"]*\""#, { $0.string }),
            (#"'[^']*'"#, { $0.string }),

            // Booleans
            (#"\b(true|false)\b"#, { $0.keyword }),

            // Numbers
            (#"\b\d+\.?\d*\b"#, { $0.number })
        ]
    }
}

// swiftlint:enable line_length
