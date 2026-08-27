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
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
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

    var displayName: String {
        rawValue
    }

    var fileExtensions: [String] {
        switch self {
        case .plainText: return ["txt", "text"]
        case .swift: return ["swift"]
        case .python: return ["py", "pyw"]
        case .javascript: return ["js", "jsx", "ts", "tsx"]
        case .php: return ["php", "phtml", "php3", "php4", "php5", "phps"]
        case .json: return ["json"]
        case .html: return ["html", "htm"]
        case .css: return ["css", "scss", "sass", "less"]
        case .markdown: return ["md", "markdown"]
        case .xml: return ["xml", "plist"]
        case .sql: return ["sql"]
        case .shell: return ["sh", "bash", "zsh"]
        case .yaml: return ["yml", "yaml"]
        }
    }

    static func detect(from url: URL) -> SyntaxLanguage {
        let ext = url.pathExtension.lowercased()
        for language in SyntaxLanguage.allCases where language.fileExtensions.contains(ext) {
            return language
        }
        return .plainText
    }
}
