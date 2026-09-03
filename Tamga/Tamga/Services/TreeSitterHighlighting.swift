import AppKit
import Neon
import SwiftTreeSitter
import SwiftTreeSitterLayer
import TreeSitterBash
import TreeSitterC
import TreeSitterCPP
import TreeSitterCSS
import TreeSitterGo
import TreeSitterHTML
import TreeSitterJSON
import TreeSitterJava
import TreeSitterJavaScript
import TreeSitterPHP
import TreeSitterPython
import TreeSitterRust
import TreeSitterSQL
import TreeSitterSwift
import TreeSitterXML
import TreeSitterYAML

// MARK: - Capture → Theme mapping

/// Maps tree-sitter highlight capture names to Tamga's existing ``SyntaxHighlighter/Theme``
/// colors so the tree-sitter engine reproduces the regex highlighter's look.
///
/// Pure value mapping; carries no tree-sitter state. Neon calls this once per token
/// and overlays the result as TextKit-1 temporary attributes, so every token must
/// carry an explicit foreground (unmapped captures fall back to the theme default).
enum TreeSitterTheme {
    /// Returns text attributes (font + foreground) for a tree-sitter capture name
    /// such as `keyword`, `string.special`, or `function.method`.
    static func attributes(forCapture capture: String, isDarkMode: Bool, font: NSFont) -> [NSAttributedString.Key: Any] {
        let theme = isDarkMode ? SyntaxHighlighter.Theme.dark : SyntaxHighlighter.Theme.light
        let color = color(forCapture: capture, theme: theme) ?? theme.foreground
        return [.font: font, .foregroundColor: color]
    }

    /// Theme colour per capture root. Extend this when a grammar's `highlights.scm`
    /// introduces a capture name that is not covered yet.
    private static let captureColors: [String: KeyPath<SyntaxHighlighter.Theme, NSColor>] = [
        "keyword": \.keyword,
        "conditional": \.keyword,
        "repeat": \.keyword,
        "include": \.keyword,
        "import": \.keyword,
        "storageclass": \.keyword,
        "define": \.keyword,
        "operator": \.operator,
        "string": \.string,
        "character": \.string,
        "escape": \.string,
        "comment": \.comment,
        "number": \.number,
        "float": \.number,
        "boolean": \.number,
        "constant": \.number,
        "function": \.function,
        "method": \.function,
        "constructor": \.function,
        "type": \.type,
        "namespace": \.type,
        "module": \.type,
        "variable": \.variable,
        "parameter": \.variable,
        "property": \.variable,
        "field": \.variable,
        "label": \.variable,
        "attribute": \.attribute,
        "tag": \.tag
    ]

    /// Longest-prefix match on dotted capture names; returns nil for captures with
    /// no themed color (caller substitutes the base foreground).
    private static func color(forCapture capture: String, theme: SyntaxHighlighter.Theme) -> NSColor? {
        let root = capture.split(separator: ".").first.map(String.init) ?? capture
        guard let keyPath = captureColors[root] else { return nil }
        return theme[keyPath: keyPath]
    }
}

// MARK: - Language resolution

/// Resolves a Tamga ``SyntaxLanguage`` to a tree-sitter root configuration plus an
/// injection language provider. Only languages in ``migratedLanguages`` are driven by
/// tree-sitter; everything else stays on the regex ``SyntaxHighlighter``.
///
/// Query files are loaded by explicit bundle name (`TamgaGrammars_<Target>`) because
/// the vendored grammar package does not follow SwiftTreeSitter's default
/// `TreeSitter<Name>_TreeSitter<Name>` auto-discovery convention.
enum TreeSitterLanguageResolver {
    /// Languages currently driven by tree-sitter. Kept in sync with ``setup(for:)``.
    static let migratedLanguages: Set<SyntaxLanguage> = [
        .html, .javascript, .css, .python, .json, .xml, .shell, .yaml, .swift, .sql, .php,
        .go, .rust, .c, .java, .cpp
    ]

    /// A resolved tree-sitter setup: the root language plus a provider for embedded
    /// (injected) languages.
    struct Setup {
        let root: LanguageConfiguration
        let languageProvider: LanguageLayer.LanguageProvider
    }

    /// Builds a grammar configuration, loading its queries by explicit bundle name
    /// (`TamgaGrammars_<Target>`) since the vendored package does not follow
    /// SwiftTreeSitter's default `TreeSitter<Name>_TreeSitter<Name>` convention.
    /// Returns nil on load failure so the caller falls back to the regex highlighter.
    private static func config(_ language: OpaquePointer, _ name: String, bundle: String) -> LanguageConfiguration? {
        try? LanguageConfiguration(language, name: name, bundleName: bundle)
    }

    // Built once, lazily; LanguageConfiguration is immutable and reusable across views.
    private static let htmlConfiguration = config(tree_sitter_html(), "html", bundle: "TamgaGrammars_TreeSitterHTML")
    private static let javascriptConfiguration = config(tree_sitter_javascript(), "javascript", bundle: "TamgaGrammars_TreeSitterJavaScript")
    private static let cssConfiguration = config(tree_sitter_css(), "css", bundle: "TamgaGrammars_TreeSitterCSS")
    private static let pythonConfiguration = config(tree_sitter_python(), "python", bundle: "TamgaGrammars_TreeSitterPython")
    private static let jsonConfiguration = config(tree_sitter_json(), "json", bundle: "TamgaGrammars_TreeSitterJSON")
    private static let bashConfiguration = config(tree_sitter_bash(), "bash", bundle: "TamgaGrammars_TreeSitterBash")
    private static let yamlConfiguration = config(tree_sitter_yaml(), "yaml", bundle: "TamgaGrammars_TreeSitterYAML")
    private static let xmlConfiguration = config(tree_sitter_xml(), "xml", bundle: "TamgaGrammars_TreeSitterXML")
    private static let swiftConfiguration = config(tree_sitter_swift(), "swift", bundle: "TamgaGrammars_TreeSitterSwift")
    private static let sqlConfiguration = config(tree_sitter_sql(), "sql", bundle: "TamgaGrammars_TreeSitterSQL")
    private static let phpConfiguration = config(tree_sitter_php(), "php", bundle: "TamgaGrammars_TreeSitterPHP")
    private static let goConfiguration = config(tree_sitter_go(), "go", bundle: "TamgaGrammars_TreeSitterGo")
    private static let rustConfiguration = config(tree_sitter_rust(), "rust", bundle: "TamgaGrammars_TreeSitterRust")
    private static let cConfiguration = config(tree_sitter_c(), "c", bundle: "TamgaGrammars_TreeSitterC")
    private static let javaConfiguration = config(tree_sitter_java(), "java", bundle: "TamgaGrammars_TreeSitterJava")
    private static let cppConfiguration = config(tree_sitter_cpp(), "cpp", bundle: "TamgaGrammars_TreeSitterCPP")

    /// Maps an injection language name (from a host grammar's `injections.scm`) to a
    /// child configuration. Names are taken from the actual query files, not guessed:
    /// HTML injects `javascript` (`<script>`) and `css` (`<style>`).
    private static let injectionProvider: LanguageLayer.LanguageProvider = { name in
        switch name {
        case "javascript", "js": return javascriptConfiguration
        case "css": return cssConfiguration
        case "html": return htmlConfiguration
        case "python": return pythonConfiguration
        case "json": return jsonConfiguration
        case "bash", "shell", "sh": return bashConfiguration
        case "yaml": return yamlConfiguration
        case "xml": return xmlConfiguration
        default: return nil
        }
    }

    /// Builds the tree-sitter setup for a migrated language, or nil if the language is
    /// not migrated or its grammar/queries failed to load (caller falls back to regex).
    /// Root configuration per migrated language. The values are closures so the map
    /// itself does not force every grammar to load; only the requested one is touched.
    /// Keep the keys in sync with ``migratedLanguages``.
    private static let rootConfigurations: [SyntaxLanguage: () -> LanguageConfiguration?] = [
        .html: { htmlConfiguration },
        .javascript: { javascriptConfiguration },
        .css: { cssConfiguration },
        .python: { pythonConfiguration },
        .json: { jsonConfiguration },
        .shell: { bashConfiguration },
        .yaml: { yamlConfiguration },
        .xml: { xmlConfiguration },
        .swift: { swiftConfiguration },
        .sql: { sqlConfiguration },
        .php: { phpConfiguration },
        .go: { goConfiguration },
        .rust: { rustConfiguration },
        .c: { cConfiguration },
        .java: { javaConfiguration },
        .cpp: { cppConfiguration }
    ]

    static func setup(for language: SyntaxLanguage) -> Setup? {
        guard let root = rootConfigurations[language]?() else { return nil }
        return Setup(root: root, languageProvider: injectionProvider)
    }
}

// MARK: - Controller

/// Owns the Neon `TextViewHighlighter` for a migrated language and manages its
/// lifecycle: attach, reconfigure on language/theme/font change, and detach when the
/// view switches to a non-migrated language (so the regex path resumes).
///
/// Neon becomes the view's `NSTextStorage` delegate and styles via TextKit-1 temporary
/// attributes (the layout manager), leaving the real text storage untouched. The base
/// font and foreground are applied to the text storage here so untokenized text renders
/// with the theme's default color.
@MainActor
final class TreeSitterHighlightController {
    private weak var textView: NSTextView?
    private var highlighter: TextViewHighlighter?
    private var configuredLanguage: SyntaxLanguage?
    private var configuredDarkMode: Bool?
    private var configuredFontKey: String?

    /// Configures (or reuses) tree-sitter highlighting for the given language.
    ///
    /// - Returns: `true` if tree-sitter now drives this view (caller must skip the regex
    ///   pass); `false` for non-migrated languages or on failure (caller uses regex).
    func configure(textView: NSTextView, language: SyntaxLanguage, isDarkMode: Bool, font: NSFont) -> Bool {
        guard let setup = TreeSitterLanguageResolver.setup(for: language) else {
            detach()
            return false
        }

        let fontKey = "\(font.fontName):\(font.pointSize)"
        let alreadyConfigured =
            highlighter != nil
            && self.textView === textView
            && configuredLanguage == language
            && configuredDarkMode == isDarkMode
            && configuredFontKey == fontKey
        if alreadyConfigured { return true }

        // Rebuild from scratch on any input change.
        detach()
        self.textView = textView

        // Base attributes live on the real text storage; Neon overlays token colors as
        // temporary attributes, so untokenized ranges use these.
        let theme = isDarkMode ? SyntaxHighlighter.Theme.dark : SyntaxHighlighter.Theme.light
        textView.textColor = theme.foreground
        textView.font = font
        textView.typingAttributes = [.font: font, .foregroundColor: theme.foreground]

        let provider: TokenAttributeProvider = { token in
            TreeSitterTheme.attributes(forCapture: token.name, isDarkMode: isDarkMode, font: font)
        }

        let configuration = TextViewHighlighter.Configuration(
            languageConfiguration: setup.root,
            attributeProvider: provider,
            languageProvider: setup.languageProvider,
            locationTransformer: { _ in nil }
        )

        do {
            highlighter = try TextViewHighlighter(textView: textView, configuration: configuration)
            configuredLanguage = language
            configuredDarkMode = isDarkMode
            configuredFontKey = fontKey
            return true
        } catch {
            highlighter = nil
            return false
        }
    }

    /// Tears down the Neon highlighter and restores the text storage delegate so the
    /// regex path can take over.
    func detach() {
        if highlighter != nil {
            // Clear Neon's TextKit-1 temporary attributes so stale token colors don't
            // linger once the regex path (which uses real text-storage attributes) takes over.
            if let textView, let layoutManager = textView.layoutManager {
                let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
                layoutManager.setTemporaryAttributes([:], forCharacterRange: fullRange)
            }
            textView?.textStorage?.delegate = nil
            highlighter = nil
        }
        configuredLanguage = nil
        configuredDarkMode = nil
        configuredFontKey = nil
    }
}
