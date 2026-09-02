import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Main content view containing tabs, editor, and status bar
struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @StateObject private var documentViewModel = DocumentViewModel()
    @ObservedObject private var appState = AppState.shared

    @State private var currentDocumentInfo = DocumentInfo()
    @State private var isDropTargeted = false
    /// Caret offset reported by the editor, in UTF-16 units.
    @State private var cursorPosition = 0

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                // Sidebar
                if appState.isSidebarVisible {
                    SidebarView(tabManager: tabManager) { url in
                        openFile(url)
                    }

                    Divider()
                }

                VStack(spacing: 0) {
                    // Tab bar
                    TabBarView(tabManager: tabManager)

                    Divider()

                    // Editor (with optional split view)
                    if let activeTab = tabManager.activeTab {
                        if appState.isSplitViewEnabled {
                            HSplitView {
                                EditorView(
                                    text: Binding(
                                        get: { activeTab.content },
                                        set: { newContent in
                                            tabManager.updateContent(newContent, for: activeTab.id)
                                            updateDocumentInfo(content: newContent)
                                            documentViewModel.search(in: newContent)
                                        }
                                    ),
                                    language: activeTab.language,
                                    showLineNumbers: appState.showLineNumbers,
                                    isWordWrapEnabled: appState.isWordWrapEnabled,
                                    fontSize: appState.fontSize,
                                    fontName: appState.fontName,
                                    goToPosition: activeTab.cursorPosition,
                                    showInvisibleCharacters: appState.showInvisibleCharacters,
                                    searchMatches: activeSearchMatches,
                                    currentMatchIndex: documentViewModel.currentSearchIndex,
                                    onCursorPositionChange: { position in
                                        cursorPosition = position
                                        updateDocumentInfo(content: activeTab.content)
                                    }
                                )
                                .id("\(activeTab.id)-left")

                                EditorView(
                                    text: Binding(
                                        get: { activeTab.content },
                                        set: { newContent in
                                            tabManager.updateContent(newContent, for: activeTab.id)
                                            updateDocumentInfo(content: newContent)
                                            documentViewModel.search(in: newContent)
                                        }
                                    ),
                                    language: activeTab.language,
                                    showLineNumbers: appState.showLineNumbers,
                                    isWordWrapEnabled: appState.isWordWrapEnabled,
                                    fontSize: appState.fontSize,
                                    fontName: appState.fontName,
                                    goToPosition: activeTab.cursorPosition,
                                    showInvisibleCharacters: appState.showInvisibleCharacters,
                                    searchMatches: activeSearchMatches,
                                    currentMatchIndex: documentViewModel.currentSearchIndex,
                                    onCursorPositionChange: { position in
                                        cursorPosition = position
                                        updateDocumentInfo(content: activeTab.content)
                                    }
                                )
                                .id("\(activeTab.id)-right")
                            }
                        } else if appState.isMarkdownPreviewEnabled && activeTab.language == .markdown {
                            HSplitView {
                                EditorView(
                                    text: Binding(
                                        get: { activeTab.content },
                                        set: { newContent in
                                            tabManager.updateContent(newContent, for: activeTab.id)
                                            updateDocumentInfo(content: newContent)
                                            documentViewModel.search(in: newContent)
                                        }
                                    ),
                                    language: activeTab.language,
                                    showLineNumbers: appState.showLineNumbers,
                                    isWordWrapEnabled: appState.isWordWrapEnabled,
                                    fontSize: appState.fontSize,
                                    fontName: appState.fontName,
                                    goToPosition: activeTab.cursorPosition,
                                    showInvisibleCharacters: appState.showInvisibleCharacters,
                                    searchMatches: activeSearchMatches,
                                    currentMatchIndex: documentViewModel.currentSearchIndex,
                                    onCursorPositionChange: { position in
                                        cursorPosition = position
                                        updateDocumentInfo(content: activeTab.content)
                                    }
                                )
                                .id("\(activeTab.id)-editor")

                                MarkdownPreviewView(markdown: activeTab.content)
                                    .id("\(activeTab.id)-preview")
                            }
                        } else {
                            EditorView(
                                text: Binding(
                                    get: { activeTab.content },
                                    set: { newContent in
                                        tabManager.updateContent(newContent, for: activeTab.id)
                                        updateDocumentInfo(content: newContent)
                                        documentViewModel.search(in: newContent)
                                    }
                                ),
                                language: activeTab.language,
                                showLineNumbers: appState.showLineNumbers,
                                isWordWrapEnabled: appState.isWordWrapEnabled,
                                fontSize: appState.fontSize,
                                fontName: appState.fontName,
                                goToPosition: activeTab.cursorPosition,
                                showInvisibleCharacters: appState.showInvisibleCharacters,
                                searchMatches: activeSearchMatches,
                                currentMatchIndex: documentViewModel.currentSearchIndex,
                                onCursorPositionChange: { position in
                                    cursorPosition = position
                                    updateDocumentInfo(content: activeTab.content)
                                }
                            )
                            .id(activeTab.id)
                        }
                    } else {
                        emptyStateView
                    }

                    // Status bar
                    if appState.isStatusBarVisible, let activeTab = tabManager.activeTab {
                        Divider()

                        StatusBarView(
                            documentInfo: currentDocumentInfo,
                            language: activeTab.language,
                            encoding: activeTab.encoding,
                            onLanguageChange: { language in
                                tabManager.setLanguage(language, for: activeTab.id)
                            },
                            onEncodingChange: { encoding in
                                tabManager.setEncoding(encoding, for: activeTab.id)
                            }
                        )
                    }
                }
            }

            // Find & Replace Panel
            if documentViewModel.isSearchVisible {
                VStack {
                    Spacer().frame(height: 44)  // Below tab bar
                    FindReplaceView(
                        searchText: $documentViewModel.searchText,
                        replaceText: $documentViewModel.replaceText,
                        isVisible: $documentViewModel.isSearchVisible,
                        showReplace: $documentViewModel.isReplaceVisible,
                        matchCount: documentViewModel.searchResults.count,
                        currentMatch: documentViewModel.currentSearchIndex,
                        onFindNext: { documentViewModel.findNext() },
                        onFindPrevious: { documentViewModel.findPrevious() },
                        onReplace: { replaceCurrentMatch() },
                        onReplaceAll: { replaceAllMatches() }
                    )
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Go to Line Panel
            if documentViewModel.isGoToLineVisible {
                GoToLineView(
                    isVisible: $documentViewModel.isGoToLineVisible,
                    totalLines: totalLineCount,
                    onGoToLine: { lineNumber in
                        goToLine(lineNumber)
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }

            // Compare View
            if documentViewModel.isCompareVisible, let activeTab = tabManager.activeTab {
                CompareView(
                    leftText: activeTab.content,
                    rightText: documentViewModel.compareText,
                    leftTitle: activeTab.title,
                    rightTitle: documentViewModel.compareTitle,
                    isVisible: $documentViewModel.isCompareVisible
                )
                .background(Color(nsColor: .windowBackgroundColor))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            restoreSession()
        }
        .onDisappear {
            saveSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            saveSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            // Persist the session on every focus loss, not only when Auto Save is on, so
            // unsaved and untitled tabs survive a crash or force-quit that fires neither
            // onDisappear nor willTerminate.
            SessionService.shared.saveSessionInBackground(
                tabs: tabManager.tabs,
                activeTabId: tabManager.activeTabId
            )
        }
        .onChange(of: tabManager.activeTabId) { _ in
            if let tab = tabManager.activeTab {
                updateDocumentInfo(content: tab.content)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveAndCloseTab)) { notification in
            if let tabId = notification.object as? UUID {
                saveThenCloseTab(id: tabId)
            }
        }
        .focusedSceneValue(\.tabManager, tabManager)
        .focusedSceneValue(\.documentViewModel, documentViewModel)
        .onChange(of: documentViewModel.searchText) { _ in
            if let tab = tabManager.activeTab {
                documentViewModel.search(in: tab.content)
            }
        }
        .onChange(of: documentViewModel.isSearchVisible) { _ in
            if documentViewModel.isSearchVisible, let tab = tabManager.activeTab {
                documentViewModel.search(in: tab.content)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: documentViewModel.isSearchVisible)
        .animation(.easeInOut(duration: 0.2), value: documentViewModel.isGoToLineVisible)
        .animation(.easeInOut(duration: 0.3), value: documentViewModel.isCompareVisible)
        .onReceive(NotificationCenter.default.publisher(for: .autoSave)) { _ in
            autoSaveDirtyTabs()
        }
        .onChange(of: appState.isAutoSaveEnabled) { _ in
            // Timer is managed in AppState
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isDropTargeted {
                dropOverlay
            }
        }
    }

    // MARK: - Drag & Drop

    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.2)
            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text(String(localized: "drop.files.here"))
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        }
        .ignoresSafeArea()
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers
        where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil,
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    return
                }

                Task { @MainActor in
                    openDroppedFile(url)
                }
            }
        }
        return true
    }

    private func openDroppedFile(_ url: URL) {
        openFile(url)
    }

    private func openFile(_ url: URL) {
        do {
            let content = try FileService.shared.readFile(at: url)
            tabManager.openTab(with: url, content: content)
            appState.addRecentFile(url)
        } catch {
            print("Failed to open file: \(error)")
        }
    }

    private func openFileFromPath(_ path: String) {
        let url = URL(fileURLWithPath: path).standardized

        // A path that does not exist yet opens as a new empty buffer instead of eagerly
        // creating a stray file on disk for a possible typo. The file is written only
        // if the user saves.
        guard FileManager.default.fileExists(atPath: url.path) else {
            tabManager.openTab(with: url, content: "")
            return
        }

        // Open the file. If it cannot be decoded, warn the user instead of opening a
        // blank tab bound to the path, because saving that blank tab would overwrite
        // the real file content.
        do {
            let content = try FileService.shared.readFile(at: url)
            tabManager.openTab(with: url, content: content)
            appState.addRecentFile(url)
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "error.decoding.failed")
            alert.informativeText = url.lastPathComponent
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// Saves the tab, then closes it once the write succeeds. Used by the Save action
    /// of the unsaved-changes alert, which may target a tab that is not the active one.
    private func saveThenCloseTab(id: UUID) {
        guard let tab = tabManager.getTab(by: id) else { return }
        Task {
            let url = await documentViewModel.saveFile(
                content: tab.content,
                existingPath: tab.filePath,
                suggestedName: tab.suggestedFileName,
                encoding: FileEncoding(rawValue: tab.encoding) ?? .utf8
            )
            if let url {
                tabManager.markAsSaved(id: tab.id, filePath: url)
                tabManager.closeTab(id: tab.id)
            }
        }
    }

    // MARK: - Auto-save

    private func autoSaveDirtyTabs() {
        let dirtyTabs = tabManager.getDirtyTabs()
        for tab in dirtyTabs {
            if let filePath = tab.filePath {
                do {
                    try FileService.shared.writeFile(
                    content: tab.content,
                    to: filePath,
                    encoding: FileEncoding(rawValue: tab.encoding) ?? .utf8
                )
                    tabManager.markAsSaved(id: tab.id, filePath: filePath)
                } catch {
                    print("Auto-save failed for \(filePath.lastPathComponent): \(error)")
                }
            }
        }
    }

    // MARK: - Line Calculations

    private var totalLineCount: Int {
        guard let activeTab = tabManager.activeTab else { return 0 }
        return activeTab.content.components(separatedBy: .newlines).count
    }

    private func goToLine(_ lineNumber: Int) {
        guard let activeTab = tabManager.activeTab else { return }
        if let position = documentViewModel.goToLine(lineNumber, in: activeTab.content) {
            tabManager.updateCursorPosition(position, for: activeTab.id)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(String(localized: "no.open.files"))
                .font(.title2)
                .foregroundColor(.secondary)

            Button(String(localized: "new.document")) {
                tabManager.createNewTab()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session Management

    private func saveSession() {
        SessionService.shared.saveSession(
            tabs: tabManager.tabs,
            activeTabId: tabManager.activeTabId
        )
    }

    private func restoreSession() {
        if let session = SessionService.shared.restoreSession() {
            if !session.tabs.isEmpty {
                // Replace the default tab and restore the untitled counter alongside.
                tabManager.restoreTabs(session.tabs, activeTabId: session.activeTabId)
            }
        }

        // Process CLI files after session restore
        processPendingCLIFiles()
    }

    private func processPendingCLIFiles() {
        let pendingFiles = CLIFileQueue.pendingFiles
        CLIFileQueue.pendingFiles.removeAll()

        for path in pendingFiles {
            openFileFromPath(path)
        }
    }

    // MARK: - Document Info

    private func updateDocumentInfo(content: String) {
        currentDocumentInfo = DocumentInfo(
            content: content,
            cursorPosition: cursorPosition
        )
    }

    // MARK: - Search & Replace

    /// Match ranges for the active tab, only while the find panel is open. The four
    /// editors all render the active tab, so they share one match set; an empty list
    /// clears the search backgrounds when the panel closes.
    private var activeSearchMatches: [NSRange] {
        guard documentViewModel.isSearchVisible, let tab = tabManager.activeTab else { return [] }
        return documentViewModel.matchRanges(in: tab.content)
    }

    private func replaceCurrentMatch() {
        guard let activeTab = tabManager.activeTab else { return }

        var content = activeTab.content
        if documentViewModel.replace(in: &content) {
            tabManager.updateContent(content, for: activeTab.id)
        }
    }

    private func replaceAllMatches() {
        guard let activeTab = tabManager.activeTab else { return }

        var content = activeTab.content
        _ = documentViewModel.replaceAll(in: &content)
        tabManager.updateContent(content, for: activeTab.id)
    }
}

// MARK: - Focused Values

struct TabManagerKey: FocusedValueKey {
    typealias Value = TabManager
}

struct DocumentViewModelKey: FocusedValueKey {
    typealias Value = DocumentViewModel
}

extension FocusedValues {
    var tabManager: TabManager? {
        get { self[TabManagerKey.self] }
        set { self[TabManagerKey.self] = newValue }
    }

    var documentViewModel: DocumentViewModel? {
        get { self[DocumentViewModelKey.self] }
        set { self[DocumentViewModelKey.self] = newValue }
    }
}

#Preview {
    ContentView()
}
