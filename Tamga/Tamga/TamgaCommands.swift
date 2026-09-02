import SwiftUI

/// Every menu the app adds to or replaces in the standard macOS menu bar.
///
/// The commands reach the active window through `@FocusedValue`, so they act on whichever
/// document window is frontmost.
struct TamgaCommands: Commands {
    @FocusedValue(\.tabManager) var tabManager
    @FocusedValue(\.documentViewModel) var documentViewModel
    @ObservedObject private var appState = AppState.shared

    var body: some Commands {
        // MARK: - App Menu
        // Replaces the built-in item so the app menu and the Help menu open the
        // same about panel; the default one carries no credits.
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "about.tamga")) {
                AboutPanel.show()
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
                    if let result = await documentViewModel?.openFile() {
                        tabManager?.openTab(with: result.url, content: result.content, lineEnding: result.lineEnding)
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

            Button(String(localized: "reopen.closed.tab")) {
                tabManager?.reopenLastClosedTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(!(tabManager?.canReopenClosedTab ?? false))

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

            Button(String(localized: "remove.empty.lines")) {
                NotificationCenter.default.post(name: .removeEmptyLines, object: nil)
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
                AboutPanel.show()
            }

            Divider()

            Button(String(localized: "install.cli.tool")) {
                CLIInstaller.install()
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
            suggestedName: tab.suggestedFileName,
            encoding: FileEncoding(rawValue: tab.encoding) ?? .utf8,
            lineEnding: tab.lineEnding
        ) {
            tabManager.markAsSaved(id: tab.id, filePath: url)
        }
    }

    private func saveCurrentTabAs() async {
        guard let tabManager = tabManager,
            let tab = tabManager.activeTab
        else { return }

        if let url = await documentViewModel?.saveFileAs(
            content: tab.content,
            suggestedName: tab.suggestedFileName,
            encoding: FileEncoding(rawValue: tab.encoding) ?? .utf8,
            lineEnding: tab.lineEnding
        ) {
            tabManager.markAsSaved(id: tab.id, filePath: url)
        }
    }

    private func openRecentFile(_ url: URL) {
        do {
            let (content, lineEnding) = try FileService.shared.readFileWithLineEnding(at: url)
            tabManager?.openTab(with: url, content: content, lineEnding: lineEnding)
        } catch {
            print("Failed to open recent file: \(error)")
        }
    }

    private func printCurrentTab() {
        guard let tab = tabManager?.activeTab else { return }
        PrintService.printText(
            tab.content,
            jobName: tab.filePath?.lastPathComponent ?? tab.title,
            fontName: appState.fontName,
            fontSize: appState.fontSize
        )
    }
}
