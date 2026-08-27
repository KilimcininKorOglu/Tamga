import AppKit

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
