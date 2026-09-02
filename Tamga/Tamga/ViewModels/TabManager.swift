import Foundation
import SwiftUI

/// Manages all tabs in the application
@MainActor
class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabId: UUID?
    @Published var draggedTab: Tab?
    /// Recently closed tabs, newest last, for Reopen Closed Tab. Published so the menu
    /// item can enable itself as soon as the first tab is closed.
    @Published private(set) var closedTabs: [Tab] = []

    private var untitledCounter: Int = 1
    private var sessionSaveTimer: Timer?
    private let maxClosedTabs = 20

    var canReopenClosedTab: Bool { !closedTabs.isEmpty }

    var activeTab: Tab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { $0.id == id }
    }

    var activeTabIndex: Int? {
        guard let id = activeTabId else { return nil }
        return tabs.firstIndex { $0.id == id }
    }

    var hasUnsavedChanges: Bool {
        tabs.contains { $0.isDirty }
    }

    init() {
        // Start with one empty tab
        createNewTab()
    }

    // MARK: - Tab Operations

    func createNewTab() {
        let newTab = Tab.newUntitled(number: untitledCounter)
        untitledCounter += 1
        tabs.append(newTab)
        activeTabId = newTab.id
    }

    /// Replaces the tab list with a restored session and recomputes the untitled
    /// counter, so the next new tab continues past the highest restored "Untitled N"
    /// instead of colliding with an existing number.
    func restoreTabs(_ restoredTabs: [Tab], activeTabId: UUID?) {
        tabs = restoredTabs
        self.activeTabId = activeTabId ?? restoredTabs.first?.id

        let untitledPrefix = "\(String(localized: "untitled")) "
        let highestNumber =
            restoredTabs
            .filter { $0.filePath == nil && $0.title.hasPrefix(untitledPrefix) }
            .compactMap { Int($0.title.dropFirst(untitledPrefix.count)) }
            .max() ?? 0
        untitledCounter = highestNumber + 1
    }

    func openTab(with url: URL, content: String, lineEnding: LineEnding = .lf) {
        // Check if file is already open
        if let existingTab = tabs.first(where: { $0.filePath == url }) {
            activeTabId = existingTab.id
            return
        }

        var newTab = Tab(
            title: url.lastPathComponent,
            content: content,
            filePath: url,
            isDirty: false,
            lineEnding: lineEnding
        )
        newTab.detectLanguage()

        tabs.append(newTab)
        activeTabId = newTab.id

        AppState.shared.addRecentFile(url)
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        rememberClosedTab(tabs[index])
        tabs.remove(at: index)

        if tabs.isEmpty {
            untitledCounter = 1
            createNewTab()
        } else if activeTabId == id {
            // Select adjacent tab
            let newIndex = min(index, tabs.count - 1)
            activeTabId = tabs[newIndex].id
        }
    }

    func closeActiveTab() {
        guard let id = activeTabId else { return }
        closeTab(id: id)
    }

    /// Pushes a closed tab onto the reopen stack, skipping an empty untitled tab because
    /// reopening a blank buffer has no value. Caps the stack so it cannot grow forever.
    private func rememberClosedTab(_ tab: Tab) {
        guard tab.filePath != nil || !tab.content.isEmpty else { return }
        closedTabs.append(tab)
        if closedTabs.count > maxClosedTabs {
            closedTabs.removeFirst()
        }
    }

    /// Reopens the most recently closed tab and makes it active.
    func reopenLastClosedTab() {
        guard let tab = closedTabs.popLast() else { return }
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeAllTabs() {
        tabs.removeAll()
        untitledCounter = 1
        createNewTab()
    }

    func closeOtherTabs(except id: UUID) {
        tabs.removeAll { $0.id != id }
        activeTabId = id
    }

    func selectTab(id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabId = id
        }
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeTabId = tabs[index].id
    }

    func selectNextTab() {
        guard let currentIndex = activeTabIndex else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        activeTabId = tabs[nextIndex].id
    }

    func selectPreviousTab() {
        guard let currentIndex = activeTabIndex else { return }
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        activeTabId = tabs[prevIndex].id
    }

    // MARK: - Tab Content Updates

    func updateContent(_ content: String, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].content = content
        tabs[index].isDirty = true
        tabs[index].lastModifiedAt = Date()
        scheduleSessionAutosave()
    }

    func updateCursorPosition(_ position: Int, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].cursorPosition = position
    }

    func markAsSaved(id: UUID, filePath: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].isDirty = false
        tabs[index].filePath = filePath
        tabs[index].updateTitleFromPath()
        tabs[index].detectLanguage()

        AppState.shared.addRecentFile(filePath)
    }

    /// Replaces a tab's content with a fresh read from disk and clears its dirty flag,
    /// used when the file changed underneath an unmodified tab.
    func reloadTab(id: UUID, content: String, lineEnding: LineEnding) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].content = content
        tabs[index].lineEnding = lineEnding
        tabs[index].isDirty = false
        tabs[index].lastModifiedAt = Date()
    }

    func setLanguage(_ language: SyntaxLanguage, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].language = language
    }

    /// Changes the encoding and marks the tab dirty, because the new encoding is written
    /// only on the next save (an encoding conversion).
    func setEncoding(_ encoding: String, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        guard tabs[index].encoding != encoding else { return }
        tabs[index].encoding = encoding
        tabs[index].isDirty = true
    }

    /// Changes the line-ending style and marks the tab dirty, because the choice only
    /// reaches disk on the next save.
    func setLineEnding(_ lineEnding: LineEnding, for id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        guard tabs[index].lineEnding != lineEnding else { return }
        tabs[index].lineEnding = lineEnding
        tabs[index].isDirty = true
    }

    // MARK: - Session Autosave (crash safety)

    /// Debounces a background session save after edits stop, so unsaved tabs
    /// survive an abrupt termination. Gated behind the Auto Save setting; the
    /// write itself runs off the main thread in `SessionService`.
    private func scheduleSessionAutosave() {
        sessionSaveTimer?.invalidate()
        sessionSaveTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.Defaults.sessionAutosaveDebounceInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, AppState.shared.isAutoSaveEnabled else { return }
                SessionService.shared.saveSessionInBackground(
                    tabs: self.tabs,
                    activeTabId: self.activeTabId
                )
            }
        }
    }

    // MARK: - Tab Reordering

    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
            sourceIndex >= 0, sourceIndex < tabs.count,
            destinationIndex >= 0, destinationIndex < tabs.count
        else { return }

        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)
    }

    func moveTab(id: UUID, to destinationIndex: Int) {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        moveTab(from: sourceIndex, to: destinationIndex)
    }

    // MARK: - Utility

    func getTab(by id: UUID) -> Tab? {
        tabs.first { $0.id == id }
    }

    func getDirtyTabs() -> [Tab] {
        tabs.filter { $0.isDirty }
    }
}
