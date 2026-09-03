import XCTest

@testable import Tamga

/// Tests the search, replace, and navigation logic of `DocumentViewModel`. The type is
/// `@MainActor`, so the test case is too.
@MainActor
final class DocumentViewModelTests: XCTestCase {
    func testLiteralCaseInsensitiveSearch() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "foo"
        viewModel.search(in: "Foo foo FOO food")
        XCTAssertEqual(viewModel.searchResults.count, 4)
    }

    func testCaseSensitiveSearch() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "foo"
        viewModel.isCaseSensitive = true
        viewModel.search(in: "Foo foo FOO food")
        XCTAssertEqual(viewModel.searchResults.count, 2)
    }

    func testWholeWordSearch() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "foo"
        viewModel.isWholeWord = true
        viewModel.search(in: "foo food bar.foo")
        XCTAssertEqual(viewModel.searchResults.count, 2)
    }

    func testRegexSearch() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "f.o"
        viewModel.isRegexEnabled = true
        viewModel.search(in: "foo fao fxo bar")
        XCTAssertEqual(viewModel.searchResults.count, 3)
    }

    func testInvalidRegexFlagsError() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "("
        viewModel.isRegexEnabled = true
        viewModel.search(in: "abc")
        XCTAssertTrue(viewModel.isSearchInvalid)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }

    func testReplaceAllLiteral() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "foo"
        viewModel.replaceText = "bar"
        var content = "foo foo"
        let count = viewModel.replaceAll(in: &content)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(content, "bar bar")
    }

    func testReplaceAllRegexTemplate() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "(\\w+)@(\\w+)"
        viewModel.replaceText = "$2.$1"
        viewModel.isRegexEnabled = true
        var content = "user@host"
        let count = viewModel.replaceAll(in: &content)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(content, "host.user")
    }

    func testReplaceAllLiteralKeepsDollarVerbatim() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "x"
        viewModel.replaceText = "$1"
        var content = "axb"
        _ = viewModel.replaceAll(in: &content)
        XCTAssertEqual(content, "a$1b")
    }

    func testReplaceSingleMatch() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "a"
        viewModel.replaceText = "b"
        var content = "aaa"
        viewModel.search(in: content)
        XCTAssertTrue(viewModel.replace(in: &content))
        XCTAssertEqual(content, "baa")
    }

    func testMatchRangesMapToContent() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "b"
        let content = "abcb"
        viewModel.search(in: content)
        let ranges = viewModel.matchRanges(in: content)
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges.first, NSRange(location: 1, length: 1))
    }

    func testGoToLine() {
        let viewModel = DocumentViewModel()
        let content = "l1\nl2\nl3"
        XCTAssertEqual(viewModel.goToLine(2, in: content), 3)
        XCTAssertNil(viewModel.goToLine(99, in: content))
    }

    func testHTMLExportProducesHTML() {
        let data = ExportService.htmlData(content: "let value = 1", language: .swift, fontName: "Menlo", fontSize: 13)
        let html = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(html.isEmpty)
        XCTAssertTrue(html.lowercased().contains("<html") || html.lowercased().contains("<span"))
        XCTAssertTrue(html.contains("value"))
    }

    func testFindNextAndPreviousWrap() {
        let viewModel = DocumentViewModel()
        viewModel.searchText = "a"
        viewModel.search(in: "aXa")
        XCTAssertEqual(viewModel.currentSearchIndex, 0)
        viewModel.findNext()
        XCTAssertEqual(viewModel.currentSearchIndex, 1)
        viewModel.findNext()
        XCTAssertEqual(viewModel.currentSearchIndex, 0)
        viewModel.findPrevious()
        XCTAssertEqual(viewModel.currentSearchIndex, 1)
    }
}
