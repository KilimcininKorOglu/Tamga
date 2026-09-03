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
}
