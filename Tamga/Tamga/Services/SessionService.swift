import Foundation

/// Service for saving and restoring application sessions
class SessionService {
    static let shared = SessionService()

    private let fileManager = FileManager.default
    private let sessionFileName = "session.json"

    /// Serial queue for off-main-thread session writes (frequent autosaves).
    private let saveQueue = DispatchQueue(label: "com.tamga.sessionSave", qos: .utility)

    private var applicationSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("Tamga")

        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        return appSupportDir
    }

    private var sessionFileURL: URL {
        applicationSupportDirectory.appendingPathComponent(sessionFileName)
    }

    private init() {}

    // MARK: - Session Data

    struct SessionData: Codable {
        let tabs: [TabData]
        let activeTabId: UUID?
        let savedAt: Date

        struct TabData: Codable {
            let id: UUID
            let title: String
            let content: String
            let filePath: String?
            let cursorPosition: Int
            let scrollPosition: CGFloat
            let languageRaw: String
            let encoding: String
            let createdAt: Date
            let lastModifiedAt: Date
            let isDirty: Bool?
        }
    }

    // MARK: - Save Session

    /// Terminal-event save (onDisappear, willTerminate). Runs synchronously on the
    /// serial queue so it waits for any in-flight background save and writes last,
    /// making the newest snapshot the one that survives.
    func saveSession(tabs: [Tab], activeTabId: UUID?) {
        saveQueue.sync {
            performSave(tabs: tabs, activeTabId: activeTabId)
        }
    }

    private func performSave(tabs: [Tab], activeTabId: UUID?) {
        let tabData = tabs.map { tab in
            SessionData.TabData(
                id: tab.id,
                title: tab.title,
                content: tab.content,
                filePath: tab.filePath?.path,
                cursorPosition: tab.cursorPosition,
                scrollPosition: tab.scrollPosition,
                languageRaw: tab.language.rawValue,
                encoding: tab.encoding,
                createdAt: tab.createdAt,
                lastModifiedAt: tab.lastModifiedAt,
                isDirty: tab.isDirty
            )
        }

        let sessionData = SessionData(
            tabs: tabData,
            activeTabId: activeTabId,
            savedAt: Date()
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessionData)
            try data.write(to: sessionFileURL, options: .atomic)
        } catch {
            print("Failed to save session: \(error)")
        }
    }

    /// Saves the session off the main thread on a serial queue.
    /// Use for frequent autosaves (typing debounce, focus loss). Terminal-event
    /// saves must stay synchronous so the write completes before the process exits.
    func saveSessionInBackground(tabs: [Tab], activeTabId: UUID?) {
        saveQueue.async { [weak self] in
            self?.performSave(tabs: tabs, activeTabId: activeTabId)
        }
    }

    // MARK: - Restore Session

    func restoreSession() -> (tabs: [Tab], activeTabId: UUID?)? {
        guard fileManager.fileExists(atPath: sessionFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: sessionFileURL)
            let sessionData = try JSONDecoder().decode(SessionData.self, from: data)

            let tabs = sessionData.tabs.map { tabData -> Tab in
                Tab(
                    id: tabData.id,
                    title: tabData.title,
                    content: tabData.content,
                    filePath: tabData.filePath.map { URL(fileURLWithPath: $0) },
                    isDirty: tabData.isDirty ?? (tabData.filePath == nil && !tabData.content.isEmpty),
                    cursorPosition: tabData.cursorPosition,
                    scrollPosition: tabData.scrollPosition,
                    language: SyntaxLanguage(rawValue: tabData.languageRaw) ?? .plainText,
                    encoding: tabData.encoding,
                    createdAt: tabData.createdAt,
                    lastModifiedAt: tabData.lastModifiedAt
                )
            }

            return (tabs, sessionData.activeTabId)
        } catch {
            print("Failed to restore session: \(error)")
            // Move the unreadable file aside so the next save does not overwrite it.
            // The preserved copy keeps the previous tabs available for manual recovery.
            quarantineCorruptSession()
            return nil
        }
    }

    /// Renames an unreadable session file so a fresh session can be written without
    /// destroying the corrupt one, which may still hold recoverable tab content.
    private func quarantineCorruptSession() {
        let backupURL = applicationSupportDirectory.appendingPathComponent(
            "session-corrupt-\(Int(Date().timeIntervalSince1970)).json"
        )
        try? fileManager.moveItem(at: sessionFileURL, to: backupURL)
    }

    // MARK: - Clear Session

    func clearSession() {
        try? fileManager.removeItem(at: sessionFileURL)
    }
}
