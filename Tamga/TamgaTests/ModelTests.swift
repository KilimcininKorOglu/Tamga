import XCTest

@testable import Tamga

/// Tests the pure model helpers: language detection, line-ending detection, and the
/// encoding table.
final class ModelTests: XCTestCase {
    func testDetectLanguageByExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/a/b.swift")), .swift)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/a/b.py")), .python)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/a/b.json")), .json)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/a/b.unknownext")), .plainText)
    }

    func testDetectDotfileEnv() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/a/.env")), .toml)
    }

    func testDetectDockerfileByName() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/a/Dockerfile")), .dockerfile)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/a/Dockerfile.dev")), .dockerfile)
    }

    func testLineEndingDetect() {
        XCTAssertEqual(LineEnding.detect(from: "a\r\nb"), .crlf)
        XCTAssertEqual(LineEnding.detect(from: "a\rb"), .cr)
        XCTAssertEqual(LineEnding.detect(from: "a\nb"), .lf)
    }

    func testLineEndingSequence() {
        XCTAssertEqual(LineEnding.lf.sequence, "\n")
        XCTAssertEqual(LineEnding.crlf.sequence, "\r\n")
        XCTAssertEqual(LineEnding.cr.sequence, "\r")
    }

    func testEncodingRoundTrip() {
        for fileEncoding in FileEncoding.allCases {
            let sample = "abc"
            guard let data = sample.data(using: fileEncoding.encoding) else {
                XCTFail("\(fileEncoding.rawValue) failed to encode")
                continue
            }
            XCTAssertEqual(
                String(data: data, encoding: fileEncoding.encoding),
                sample,
                fileEncoding.rawValue
            )
        }
    }

    func testEncodingBOMDetect() {
        let utf8BOM = Data([0xEF, 0xBB, 0xBF]) + Data("hi".utf8)
        XCTAssertEqual(FileEncoding.detect(from: utf8BOM), .utf8)
    }

    /// Loads each migrated grammar through the resolver. A non-nil `Setup` proves the
    /// grammar symbol links, its query bundle resolves by name, and its highlights.scm
    /// compiles against that grammar, because a mismatch makes LanguageConfiguration throw.
    func testMigratedGrammarsLoad() {
        for language in TreeSitterLanguageResolver.migratedLanguages {
            XCTAssertNotNil(
                TreeSitterLanguageResolver.setup(for: language),
                "\(language.rawValue) grammar failed to load"
            )
        }
    }

    /// The markdown block grammar injects its inline grammar for spans and emphasis;
    /// resolve that injection to prove the inline grammar and its queries also load.
    func testMarkdownInlineInjectionResolves() {
        guard let setup = TreeSitterLanguageResolver.setup(for: .markdown) else {
            XCTFail("markdown grammar failed to load")
            return
        }
        XCTAssertNotNil(setup.languageProvider("markdown_inline"))
    }
}

/// Tests the auto-close bracket behaviour of the editor's text view. These drive the
/// programmatic `insertText` entry point directly, so no window or key events are needed.
@MainActor
final class AutoCloseTests: XCTestCase {
    private func makeTextView() -> TamgaTextView {
        let textView = TamgaTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        textView.isEditable = true
        textView.string = ""
        return textView
    }

    func testTypingOpenBracketInsertsPairAndCentersCaret() {
        AppState.shared.isAutoCloseBracketsEnabled = true
        let textView = makeTextView()
        textView.insertText("(", replacementRange: textView.selectedRange())
        XCTAssertEqual(textView.string, "()")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 1, length: 0))
    }

    func testTypingClosingBracketOverAnExistingOneStepsOver() {
        AppState.shared.isAutoCloseBracketsEnabled = true
        let textView = makeTextView()
        textView.string = "()"
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.insertText(")", replacementRange: textView.selectedRange())
        XCTAssertEqual(textView.string, "()")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 0))
    }

    func testTypingBracketWrapsSelection() {
        AppState.shared.isAutoCloseBracketsEnabled = true
        let textView = makeTextView()
        textView.string = "abc"
        textView.setSelectedRange(NSRange(location: 0, length: 3))
        textView.insertText("[", replacementRange: textView.selectedRange())
        XCTAssertEqual(textView.string, "[abc]")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 1, length: 3))
    }

    func testNormalCharacterTypingIsUnaffected() {
        AppState.shared.isAutoCloseBracketsEnabled = true
        let textView = makeTextView()
        textView.insertText("a", replacementRange: textView.selectedRange())
        textView.insertText("b", replacementRange: textView.selectedRange())
        XCTAssertEqual(textView.string, "ab")
    }

    func testDisabledToggleSkipsAutoClose() {
        AppState.shared.isAutoCloseBracketsEnabled = false
        let textView = makeTextView()
        textView.insertText("(", replacementRange: textView.selectedRange())
        XCTAssertEqual(textView.string, "(")
        AppState.shared.isAutoCloseBracketsEnabled = true
    }

    func testCompletionsSuggestDocumentWords() {
        let textView = makeTextView()
        textView.string = "counter counterValue count other"
        let range = NSRange(location: 0, length: 5)  // "count"
        let suggestions = textView.completions(forPartialWordRange: range, indexOfSelectedItem: nil)
        XCTAssertEqual(suggestions, ["counter", "counterValue"])
    }

    func testCompletionsReturnNilWhenNoMatch() {
        let textView = makeTextView()
        textView.string = "alpha beta"
        let range = NSRange(location: 0, length: 5)  // "alpha", no longer word starts with it
        XCTAssertNil(textView.completions(forPartialWordRange: range, indexOfSelectedItem: nil))
    }
}
