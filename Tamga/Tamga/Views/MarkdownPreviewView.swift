// swift-format-ignore-file
// The HTML and CSS template below lives in a multi-line string literal. The
// formatter reindents that literal's contents and breaks the markup, so this
// file stays out of its reach.

import SwiftUI
import WebKit

/// A view that renders markdown content as HTML
struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(from: markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func generateHTML(from markdown: String) -> String {
        let convertedContent = convertMarkdownToHTML(markdown)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
            \(Self.stylesheet)
            </style>
        </head>
        <body>
            \(convertedContent)
        </body>
        </html>
        """
    }

    /// Stylesheet for the preview document. Held apart from the page template
    /// so the generator stays short enough to read at a glance.
    private static let stylesheet = """
        :root {
            color-scheme: light dark;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            padding: 20px;
            max-width: 800px;
            margin: 0 auto;
            color: #333;
        }
        @media (prefers-color-scheme: dark) {
            body {
                color: #e0e0e0;
                background-color: transparent;
            }
            a { color: #6db3f2; }
            code { background-color: #3a3a3a; }
            pre { background-color: #2d2d2d; }
            blockquote { border-left-color: #555; }
            hr { border-color: #555; }
            table th, table td { border-color: #555; }
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }
        h1 { font-size: 2em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        code {
            background-color: #f6f8fa;
            padding: 0.2em 0.4em;
            border-radius: 3px;
            font-family: 'SF Mono', Menlo, Monaco, monospace;
            font-size: 85%;
        }
        pre {
            background-color: #f6f8fa;
            padding: 16px;
            overflow: auto;
            border-radius: 6px;
        }
        pre code {
            background-color: transparent;
            padding: 0;
        }
        blockquote {
            margin: 0;
            padding: 0 1em;
            color: #6a737d;
            border-left: 0.25em solid #dfe2e5;
        }
        a { color: #0366d6; text-decoration: none; }
        a:hover { text-decoration: underline; }
        img { max-width: 100%; }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 16px 0;
        }
        table th, table td {
            border: 1px solid #dfe2e5;
            padding: 6px 13px;
        }
        table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }
        @media (prefers-color-scheme: dark) {
            table tr:nth-child(2n) {
                background-color: #2d2d2d;
            }
        }
        hr {
            border: 0;
            border-top: 1px solid #eee;
            margin: 24px 0;
        }
        ul, ol {
            padding-left: 2em;
        }
        li + li {
            margin-top: 0.25em;
        }
        """

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown

        // Escape HTML special characters first (but preserve markdown)
        html = html.replacingOccurrences(of: "&", with: "&amp;")
        html = html.replacingOccurrences(of: "<", with: "&lt;")
        html = html.replacingOccurrences(of: ">", with: "&gt;")

        // Code blocks (must be done before other transformations)
        let codeBlockPattern = "```([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            html = regex.stringByReplacingMatches(
                in: html,
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<pre><code>$1</code></pre>"
            )
        }

        // Inline code
        let inlineCodePattern = "`([^`]+)`"
        if let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []) {
            html = regex.stringByReplacingMatches(
                in: html,
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<code>$1</code>"
            )
        }

        // Headers
        html = html.replacingOccurrences(of: "(?m)^###### (.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##### (.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)

        // Bold
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "__(.+?)__", with: "<strong>$1</strong>", options: .regularExpression)

        // Italic
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(of: "_(.+?)_", with: "<em>$1</em>", options: .regularExpression)

        // Strikethrough
        html = html.replacingOccurrences(of: "~~(.+?)~~", with: "<del>$1</del>", options: .regularExpression)

        // Links
        html = html.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)

        // Images
        html = html.replacingOccurrences(of: "!\\[([^\\]]*?)\\]\\(([^)]+)\\)", with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)

        // Blockquotes
        html = html.replacingOccurrences(of: "(?m)^&gt; (.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)

        // Horizontal rules
        html = html.replacingOccurrences(of: "(?m)^---+$", with: "<hr>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\*\\*\\*+$", with: "<hr>", options: .regularExpression)

        // Unordered lists
        html = html.replacingOccurrences(of: "(?m)^[*+-] (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Ordered lists
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Wrap consecutive list items
        let liPattern = "(<li>.*?</li>\\n?)+"
        if let regex = try? NSRegularExpression(pattern: liPattern, options: []) {
            html = regex.stringByReplacingMatches(
                in: html,
                range: NSRange(html.startIndex..., in: html),
                withTemplate: "<ul>$0</ul>"
            )
        }

        // Paragraphs (convert double newlines)
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"

        // Clean up empty paragraphs
        html = html.replacingOccurrences(of: "<p></p>", with: "")
        html = html.replacingOccurrences(of: "<p>\\s*</p>", with: "", options: .regularExpression)

        // Fix paragraphs around block elements
        let blockElements = ["h1", "h2", "h3", "h4", "h5", "h6", "pre", "blockquote", "ul", "ol", "hr"]
        for element in blockElements {
            html = html.replacingOccurrences(of: "<p><\(element)>", with: "<\(element)>")
            html = html.replacingOccurrences(of: "</\(element)></p>", with: "</\(element)>")
            html = html.replacingOccurrences(of: "<p><\(element)", with: "<\(element)")
            html = html.replacingOccurrences(of: "\(element)></p>", with: "\(element)>")
        }

        return html
    }
}
