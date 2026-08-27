import AppKit

/// The about panel shown from both the app menu and the Help menu.
enum AboutPanel {
    /// Shows the standard macOS about panel, which renders the app icon from the asset
    /// catalog, followed by the description and the author credit.
    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Tamga",
            .credits: credits()
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let credits = NSMutableAttributedString(
            string: String(localized: "about.description") + "\n\n",
            attributes: baseAttributes
        )
        credits.append(NSAttributedString(string: "\(Constants.Author.name)\n", attributes: baseAttributes))

        var linkAttributes = baseAttributes
        linkAttributes[.link] = URL(string: Constants.Author.profileURL)
        credits.append(NSAttributedString(string: Constants.Author.handle, attributes: linkAttributes))

        return credits
    }
}
