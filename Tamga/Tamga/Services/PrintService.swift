import AppKit
import UniformTypeIdentifiers

/// Exports the active document to HTML or PDF, with syntax colors from the regex
/// highlighter (colored for the regex-supported languages, plain otherwise).
enum ExportService {
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 36

    /// Builds the highlighted, monospaced attributed string once for both exporters.
    private static func attributed(_ content: String, _ language: SyntaxLanguage, _ fontName: String, _ fontSize: CGFloat) -> NSAttributedString {
        let highlighted = SyntaxHighlighter.shared.highlight(text: content, language: language, isDarkMode: false)
        let mutable = NSMutableAttributedString(attributedString: highlighted)
        let font = NSFont(name: fontName, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        mutable.addAttribute(.font, value: font, range: NSRange(location: 0, length: mutable.length))
        return mutable
    }

    /// Renders the highlighted content to HTML bytes. Split out from the save flow so it
    /// can be tested without the save panel.
    static func htmlData(content: String, language: SyntaxLanguage, fontName: String, fontSize: CGFloat) -> Data? {
        let text = attributed(content, language, fontName, fontSize)
        return try? text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        )
    }

    static func exportHTML(content: String, language: SyntaxLanguage, fontName: String, fontSize: CGFloat, suggestedName: String) {
        guard
            let url = savePanelURL(suggestedName: suggestedName, ext: "html", contentType: .html),
            let data = htmlData(content: content, language: language, fontName: fontName, fontSize: fontSize)
        else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    static func exportPDF(content: String, language: SyntaxLanguage, fontName: String, fontSize: CGFloat, suggestedName: String) {
        guard let url = savePanelURL(suggestedName: suggestedName, ext: "pdf", contentType: .pdf) else { return }

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.textStorage?.setAttributedString(attributed(content, language, fontName, fontSize))

        let info = NSPrintInfo(
            dictionary: [
                .jobDisposition: NSPrintInfo.JobDisposition.save,
                .jobSavingURL: url,
            ]
        )
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.topMargin = margin
        info.bottomMargin = margin
        info.leftMargin = margin
        info.rightMargin = margin

        let operation = NSPrintOperation(view: textView, printInfo: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.run()
    }

    /// Presents a save panel and returns the chosen URL with the right extension.
    private static func savePanelURL(suggestedName: String, ext: String, contentType: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = (suggestedName as NSString).deletingPathExtension + ".\(ext)"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// Sends editor text to the printer through the standard macOS print panel.
enum PrintService {
    private static let pageWidth: CGFloat = 612  // US Letter width in points
    private static let pageHeight: CGFloat = 792  // US Letter height in points
    private static let margin: CGFloat = 36

    /// Lays the text out in an offscreen text view and runs the print operation.
    static func printText(_ text: String, jobName: String, fontName: String, fontSize: CGFloat) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.string = text
        textView.font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = NSColor.textColor

        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.topMargin = margin
        printInfo.bottomMargin = margin
        printInfo.leftMargin = margin
        printInfo.rightMargin = margin
        printInfo.jobDisposition = .spool

        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.jobTitle = jobName
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }
}
