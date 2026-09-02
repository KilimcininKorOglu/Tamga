import Foundation
import SwiftUI

/// Represents a single tab in the editor
struct Tab: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var filePath: URL?
    var isDirty: Bool
    var cursorPosition: Int
    var scrollPosition: CGFloat
    var language: SyntaxLanguage
    var encoding: String
    var lineEnding: LineEnding
    var createdAt: Date
    var lastModifiedAt: Date

    init(
        id: UUID = UUID(),
        title: String = String(localized: "untitled"),
        content: String = "",
        filePath: URL? = nil,
        isDirty: Bool = false,
        cursorPosition: Int = 0,
        scrollPosition: CGFloat = 0,
        language: SyntaxLanguage = .plainText,
        encoding: String = "UTF-8",
        lineEnding: LineEnding = .lf,
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.filePath = filePath
        self.isDirty = isDirty
        self.cursorPosition = cursorPosition
        self.scrollPosition = scrollPosition
        self.language = language
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, content, filePath, isDirty, cursorPosition, scrollPosition
        case language, encoding, lineEnding, createdAt, lastModifiedAt
    }

    /// Decodes a tab, tolerating a session written before `lineEnding` existed, so an
    /// older `session.json` still restores instead of dropping every tab.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        filePath = try container.decodeIfPresent(URL.self, forKey: .filePath)
        isDirty = try container.decode(Bool.self, forKey: .isDirty)
        cursorPosition = try container.decode(Int.self, forKey: .cursorPosition)
        scrollPosition = try container.decode(CGFloat.self, forKey: .scrollPosition)
        language = try container.decode(SyntaxLanguage.self, forKey: .language)
        encoding = try container.decode(String.self, forKey: .encoding)
        lineEnding = try container.decodeIfPresent(LineEnding.self, forKey: .lineEnding) ?? .lf
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastModifiedAt = try container.decode(Date.self, forKey: .lastModifiedAt)
    }

    /// Creates a new untitled tab
    static func newUntitled(number: Int = 1) -> Tab {
        Tab(title: "\(String(localized: "untitled")) \(number)")
    }

    /// File name proposed in the save panel.
    ///
    /// Uses the tab's own title so a never-saved tab keeps its identity, and appends the
    /// language's primary extension when the title carries none.
    var suggestedFileName: String {
        if let path = filePath {
            return path.lastPathComponent
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "untitled") : trimmed
        guard (name as NSString).pathExtension.isEmpty,
            let fileExtension = language.fileExtensions.first
        else {
            return name
        }
        return "\(name).\(fileExtension)"
    }

    /// Updates the title based on file path
    mutating func updateTitleFromPath() {
        if let path = filePath {
            title = path.lastPathComponent
        }
    }

    /// Detects language from file extension
    mutating func detectLanguage() {
        guard let path = filePath else {
            language = .plainText
            return
        }
        language = SyntaxLanguage.detect(from: path)
    }

    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id
    }
}

/// Supported syntax highlighting languages
enum SyntaxLanguage: String, Codable, CaseIterable {
    case plainText = "Plain Text"
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript"
    case php = "PHP"
    case json = "JSON"
    case html = "HTML"
    case css = "CSS"
    case markdown = "Markdown"
    case xml = "XML"
    case sql = "SQL"
    case shell = "Shell"
    case yaml = "YAML"
    case toml = "TOML"

    var displayName: String {
        rawValue
    }

    var fileExtensions: [String] {
        switch self {
        case .plainText: return ["txt", "text", "log"]
        case .swift: return ["swift"]
        case .python: return ["py", "pyw", "pyi"]
        case .javascript: return ["js", "jsx", "ts", "tsx", "mjs", "cjs"]
        case .php: return ["php", "phtml", "php3", "php4", "php5", "phps"]
        case .json: return ["json", "jsonc", "geojson"]
        case .html: return ["html", "htm", "xhtml"]
        case .css: return ["css", "scss", "sass", "less", "pcss"]
        case .markdown: return ["md", "markdown", "mdown", "mkd", "mdwn"]
        case .xml: return ["xml", "plist", "svg", "xsd", "xsl", "xslt"]
        case .sql: return ["sql"]
        case .shell: return ["sh", "bash", "zsh", "ksh", "fish"]
        case .yaml: return ["yml", "yaml"]
        case .toml: return ["toml", "ini", "conf", "cfg", "env"]
        }
    }

    static func detect(from url: URL) -> SyntaxLanguage {
        var ext = url.pathExtension.lowercased()
        if ext.isEmpty {
            // Dotfiles like `.env` carry no path extension; treat the name after the
            // leading dot as the extension so they still map to a language.
            let name = url.lastPathComponent
            if name.hasPrefix("."), !name.dropFirst().contains(".") {
                ext = String(name.dropFirst()).lowercased()
            }
        }
        for language in SyntaxLanguage.allCases where language.fileExtensions.contains(ext) {
            return language
        }
        return .plainText
    }
}
