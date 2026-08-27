import SwiftUI

@main
struct TamgaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.tabManager) var tabManager
    @FocusedValue(\.documentViewModel) var documentViewModel
    @ObservedObject private var appState = AppState.shared

    init() {
        processCommandLineArguments()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appState.currentTheme.colorScheme)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            // MARK: - App Menu
            // Replaces the built-in item so the app menu and the Help menu open the
            // same about panel; the default one carries no credits.
            CommandGroup(replacing: .appInfo) {
                Button(String(localized: "about.tamga")) {
                    showAboutPanel()
                }
            }

            // MARK: - File Menu
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "new.tab")) {
                    tabManager?.createNewTab()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(String(localized: "open")) {
                    Task {
                        if let (url, content) = await documentViewModel?.openFile() {
                            tabManager?.openTab(with: url, content: content)
                        }
                    }
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button(String(localized: "save")) {
                    Task {
                        await saveCurrentTab()
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(tabManager?.activeTab == nil)

                Button(String(localized: "save.as")) {
                    Task {
                        await saveCurrentTabAs()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(tabManager?.activeTab == nil)

                Toggle(String(localized: "auto.save"), isOn: $appState.isAutoSaveEnabled)

                Divider()

                Button(String(localized: "compare.with.file")) {
                    Task {
                        await documentViewModel?.openFileForCompare()
                    }
                }
                .disabled(tabManager?.activeTab == nil)

                Divider()

                Button(String(localized: "print")) {
                    printCurrentTab()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(tabManager?.activeTab == nil)

                Divider()

                Button(String(localized: "close.tab")) {
                    tabManager?.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(tabManager?.activeTab == nil)

                Button(String(localized: "close.all.tabs")) {
                    tabManager?.closeAllTabs()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift, .option])

                Divider()

                // Recent files submenu
                Menu(String(localized: "recent.files")) {
                    if appState.recentFiles.isEmpty {
                        Text(String(localized: "no.recent.files"))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appState.recentFiles, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                openRecentFile(url)
                            }
                        }

                        Divider()

                        Button(String(localized: "clear.recent")) {
                            appState.clearRecentFiles()
                        }
                    }
                }
            }

            // MARK: - Edit Menu
            CommandGroup(after: .undoRedo) {
                Divider()

                Button(String(localized: "find")) {
                    documentViewModel?.toggleSearch()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button(String(localized: "find.next")) {
                    documentViewModel?.findNext()
                }
                .keyboardShortcut("g", modifiers: .command)

                Button(String(localized: "find.previous")) {
                    documentViewModel?.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button(String(localized: "replace.menu")) {
                    documentViewModel?.showReplace()
                }
                .keyboardShortcut("f", modifiers: [.command, .option])

                Divider()

                Button(String(localized: "go.to.line")) {
                    documentViewModel?.toggleGoToLine()
                }
                .keyboardShortcut("l", modifiers: .command)

                Divider()

                Button(String(localized: "duplicate.line")) {
                    NotificationCenter.default.post(name: .duplicateLine, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button(String(localized: "move.line.up")) {
                    NotificationCenter.default.post(name: .moveLineUp, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: .option)

                Button(String(localized: "move.line.down")) {
                    NotificationCenter.default.post(name: .moveLineDown, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: .option)

                Divider()

                // Sort Lines submenu
                Menu(String(localized: "sort.lines")) {
                    Button(String(localized: "sort.lines.ascending")) {
                        NotificationCenter.default.post(name: .sortLinesAscending, object: nil)
                    }
                    Button(String(localized: "sort.lines.descending")) {
                        NotificationCenter.default.post(name: .sortLinesDescending, object: nil)
                    }
                }

                Button(String(localized: "remove.duplicate.lines")) {
                    NotificationCenter.default.post(name: .removeDuplicateLines, object: nil)
                }

                // Change Case submenu
                Menu(String(localized: "change.case")) {
                    Button(String(localized: "uppercase")) {
                        NotificationCenter.default.post(name: .uppercaseSelection, object: nil)
                    }
                    .keyboardShortcut("u", modifiers: [.command, .shift])

                    Button(String(localized: "lowercase")) {
                        NotificationCenter.default.post(name: .lowercaseSelection, object: nil)
                    }
                    .keyboardShortcut("l", modifiers: [.command, .shift])

                    Button(String(localized: "capitalize")) {
                        NotificationCenter.default.post(name: .capitalizeSelection, object: nil)
                    }
                }

                Divider()

                // JSON submenu
                Menu(String(localized: "json")) {
                    Button(String(localized: "format.json")) {
                        NotificationCenter.default.post(name: .formatJSON, object: nil)
                    }
                    .keyboardShortcut("j", modifiers: [.command, .shift])

                    Button(String(localized: "minify.json")) {
                        NotificationCenter.default.post(name: .minifyJSON, object: nil)
                    }
                }

                Divider()

                // Code Folding submenu
                Menu(String(localized: "code.folding")) {
                    Button(String(localized: "fold")) {
                        NotificationCenter.default.post(name: .foldCode, object: nil)
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

                    Button(String(localized: "unfold")) {
                        NotificationCenter.default.post(name: .unfoldCode, object: nil)
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

                    Divider()

                    Button(String(localized: "fold.all")) {
                        NotificationCenter.default.post(name: .foldAll, object: nil)
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [.command, .option, .shift])

                    Button(String(localized: "unfold.all")) {
                        NotificationCenter.default.post(name: .unfoldAll, object: nil)
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .shift])
                }
            }

            // MARK: - View Menu
            CommandGroup(after: .toolbar) {
                Divider()

                Toggle(String(localized: "sidebar"), isOn: $appState.isSidebarVisible)
                    .keyboardShortcut("b", modifiers: .command)

                Divider()

                Toggle(String(localized: "word.wrap"), isOn: $appState.isWordWrapEnabled)
                    .keyboardShortcut("w", modifiers: [.command, .option])

                Toggle(String(localized: "line.numbers"), isOn: $appState.showLineNumbers)

                Toggle(String(localized: "status.bar"), isOn: $appState.isStatusBarVisible)

                Toggle(String(localized: "split.view"), isOn: $appState.isSplitViewEnabled)
                    .keyboardShortcut("\\", modifiers: [.command])

                Toggle(String(localized: "markdown.preview"), isOn: $appState.isMarkdownPreviewEnabled)
                    .keyboardShortcut("m", modifiers: [.command, .shift])

                Toggle(String(localized: "show.invisibles"), isOn: $appState.showInvisibleCharacters)
                    .keyboardShortcut("8", modifiers: [.command, .option])

                Divider()

                Button(String(localized: "zoom.in")) {
                    appState.fontSize = min(appState.fontSize + 2, 48)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button(String(localized: "zoom.out")) {
                    appState.fontSize = max(appState.fontSize - 2, 8)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button(String(localized: "reset.zoom")) {
                    appState.fontSize = 14
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                // Theme submenu
                Menu(String(localized: "theme")) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            appState.currentTheme = theme
                        } label: {
                            HStack {
                                Text(theme.displayName)
                                if appState.currentTheme == theme {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                // Language submenu
                Menu(String(localized: "language")) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button {
                            appState.setLanguage(language)
                        } label: {
                            HStack {
                                Text(language.displayName)
                                if appState.appLanguage == language {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // MARK: - Tab Navigation
            CommandGroup(after: .windowArrangement) {
                Divider()

                Button(String(localized: "next.tab")) {
                    tabManager?.selectNextTab()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])

                Button(String(localized: "previous.tab")) {
                    tabManager?.selectPreviousTab()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])

                Divider()

                // Tab shortcuts 1-9
                ForEach(1...9, id: \.self) { index in
                    Button("Tab \(index)") {
                        tabManager?.selectTab(at: index - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                }
            }

            // MARK: - Help Menu
            CommandGroup(replacing: .help) {
                Button(String(localized: "about.tamga")) {
                    showAboutPanel()
                }

                Divider()

                Button(String(localized: "install.cli.tool")) {
                    installCLITool()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func saveCurrentTab() async {
        guard let tabManager = tabManager,
            let tab = tabManager.activeTab
        else { return }

        if let url = await documentViewModel?.saveFile(
            content: tab.content,
            existingPath: tab.filePath,
            suggestedName: tab.suggestedFileName
        ) {
            tabManager.markAsSaved(id: tab.id, filePath: url)
        }
    }

    private func saveCurrentTabAs() async {
        guard let tabManager = tabManager,
            let tab = tabManager.activeTab
        else { return }

        if let url = await documentViewModel?.saveFileAs(content: tab.content, suggestedName: tab.suggestedFileName) {
            tabManager.markAsSaved(id: tab.id, filePath: url)
        }
    }

    private func openRecentFile(_ url: URL) {
        do {
            let content = try FileService.shared.readFile(at: url)
            tabManager?.openTab(with: url, content: content)
        } catch {
            print("Failed to open recent file: \(error)")
        }
    }

    /// Shows the standard macOS about panel, which renders the app icon from the asset
    /// catalog, followed by the description and the author credit.
    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Tamga",
            .credits: aboutCredits()
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func aboutCredits() -> NSAttributedString {
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

    private func printCurrentTab() {
        guard let tab = tabManager?.activeTab else { return }

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))  // US Letter size in points
        textView.string = tab.content

        // Configure font
        let font =
            NSFont(name: appState.fontName, size: appState.fontSize) ?? NSFont.monospacedSystemFont(ofSize: appState.fontSize, weight: .regular)
        textView.font = font
        textView.textColor = NSColor.textColor

        // Configure print info
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        // Set margins
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        // Set job name
        let jobName = tab.filePath?.lastPathComponent ?? tab.title
        printInfo.jobDisposition = .spool

        // Create print operation
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.jobTitle = jobName
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true

        printOperation.run()
    }

    /// Launcher written to /usr/local/bin/tamga. It forwards every argument to the
    /// app as an absolute path, because the app is opened out of the caller's
    /// working directory.
    private static let cliLauncherScript = """
        #!/bin/bash
        # Tamga CLI - opens files from the terminal

        APP_PATH="/Applications/Tamga.app"

        if [ $# -eq 0 ]; then
            # No arguments: just launch the app
            open "$APP_PATH"
            exit 0
        fi

        # Resolve every argument to an absolute path
        args=()
        for file in "$@"; do
            if [[ "$file" = /* ]]; then
                args+=("$file")
            else
                args+=("$(pwd)/$file")
            fi
        done

        open "$APP_PATH" --args "${args[@]}"
        """

    private func installCLITool() {
        let alert = NSAlert()
        alert.messageText = String(localized: "install.cli.title")
        alert.informativeText = String(localized: "install.cli.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "install"))
        alert.addButton(withTitle: String(localized: "cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try writeCLILauncher()
            showAlert(
                title: String(localized: "install.cli.success.title"),
                message: String(localized: "install.cli.success.message"),
                style: .informational
            )
        } catch {
            showAlert(
                title: String(localized: "install.cli.error.title"),
                message: error.localizedDescription,
                style: .critical
            )
        }
    }

    /// Copies the launcher into /usr/local/bin with administrator privileges,
    /// creating the directory first when the system does not ship it.
    private func writeCLILauncher() throws {
        let fileManager = FileManager.default
        let binPath = "/usr/local/bin"
        let destinationPath = "\(binPath)/tamga"

        if !fileManager.fileExists(atPath: binPath) {
            try runAsAdministrator("mkdir -p '\(binPath)'")
        }

        let tempPath = NSTemporaryDirectory() + "tamga-cli.sh"
        try Self.cliLauncherScript.write(toFile: tempPath, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(atPath: tempPath) }

        try runAsAdministrator("cp '\(tempPath)' '\(destinationPath)' && chmod +x '\(destinationPath)'")
    }

    private func runAsAdministrator(_ shellCommand: String) throws {
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", "do shell script \"\(shellCommand)\" with administrator privileges"]
        try process.run()
        process.waitUntilExit()
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - CLI Processing

/// Stores CLI file paths to be opened after session restore
enum CLIFileQueue {
    static var pendingFiles: [String] = []
}

private func processCommandLineArguments() {
    let args = CommandLine.arguments

    // İlk argüman uygulama yolu, sonrakiler dosya yolları
    for i in 1..<args.count {
        let path = args[i]
        // Skip Xcode debug arguments
        if path.starts(with: "-") || path.contains("XCTest") {
            continue
        }

        // Store paths to be processed after session restore
        CLIFileQueue.pendingFiles.append(path)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.saveSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
