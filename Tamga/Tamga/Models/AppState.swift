import Foundation
import SwiftUI

/// Global application state
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isWordWrapEnabled: Bool = true
    @Published var isStatusBarVisible: Bool = true
    @Published var currentTheme: AppTheme = .system
    @Published var fontSize: CGFloat = 14
    @Published var fontName: String = "SF Mono"
    @Published var showLineNumbers: Bool = true
    @Published var recentFiles: [URL] = []
    @Published var isAutoSaveEnabled: Bool = false {
        didSet {
            // Reschedule the timer when the menu toggle flips, so enabling Auto Save
            // starts the periodic save in the same session instead of only after relaunch.
            guard isAutoSaveEnabled != oldValue else { return }
            setupAutoSaveTimer()
        }
    }
    @Published var autoSaveInterval: TimeInterval = 60  // seconds
    @Published var isSplitViewEnabled: Bool = false
    @Published var isSidebarVisible: Bool = false
    @Published var isMarkdownPreviewEnabled: Bool = false
    @Published var showInvisibleCharacters: Bool = false
    @Published var isMinimapVisible: Bool = false
    @Published var isIndentGuidesVisible: Bool = false
    @Published var isOccurrenceHighlightEnabled: Bool = true
    @Published var appLanguage: AppLanguage = .system

    private let userDefaults = UserDefaults.standard
    private let recentFilesKey = "recentFiles"
    private let maxRecentFiles = 10
    private var autoSaveTimer: Timer?

    private init() {
        loadSettings()
        setupAutoSaveTimer()
    }

    private func setupAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        if isAutoSaveEnabled {
            autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.triggerAutoSave()
                }
            }
        }
    }

    private func triggerAutoSave() {
        NotificationCenter.default.post(name: .autoSave, object: nil)
    }

    func loadSettings() {
        isWordWrapEnabled = userDefaults.object(forKey: "wordWrap") as? Bool ?? true
        isStatusBarVisible = userDefaults.object(forKey: "statusBar") as? Bool ?? true
        fontSize = userDefaults.object(forKey: "fontSize") as? CGFloat ?? 14
        fontName = userDefaults.string(forKey: "fontName") ?? "SF Mono"
        showLineNumbers = userDefaults.object(forKey: "lineNumbers") as? Bool ?? true
        isAutoSaveEnabled = userDefaults.object(forKey: "autoSave") as? Bool ?? false
        autoSaveInterval = userDefaults.object(forKey: "autoSaveInterval") as? TimeInterval ?? 60
        isMinimapVisible = userDefaults.object(forKey: "minimap") as? Bool ?? false
        isIndentGuidesVisible = userDefaults.object(forKey: "indentGuides") as? Bool ?? false
        isOccurrenceHighlightEnabled = userDefaults.object(forKey: "occurrenceHighlight") as? Bool ?? true

        if let themeRaw = userDefaults.string(forKey: "theme"),
            let theme = AppTheme(rawValue: themeRaw)
        {
            currentTheme = theme
        }

        if let recentData = userDefaults.data(forKey: recentFilesKey),
            let urls = try? JSONDecoder().decode([URL].self, from: recentData)
        {
            recentFiles = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        }

        if let langRaw = userDefaults.string(forKey: "appLanguage"),
            let lang = AppLanguage(rawValue: langRaw)
        {
            appLanguage = lang
            applyLanguage()
        }
    }

    func setLanguage(_ language: AppLanguage) {
        appLanguage = language
        applyLanguage()
        saveSettings()
        restartApp()
    }

    private func applyLanguage() {
        if appLanguage == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([appLanguage.code], forKey: "AppleLanguages")
        }
    }

    private func restartApp() {
        // Relaunch the app bundle, then quit. `bundleURL` is the .app itself, so no
        // force-unwrap or path gymnastics are needed.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [Bundle.main.bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    func saveSettings() {
        userDefaults.set(isWordWrapEnabled, forKey: "wordWrap")
        userDefaults.set(isStatusBarVisible, forKey: "statusBar")
        userDefaults.set(fontSize, forKey: "fontSize")
        userDefaults.set(fontName, forKey: "fontName")
        userDefaults.set(showLineNumbers, forKey: "lineNumbers")
        userDefaults.set(currentTheme.rawValue, forKey: "theme")
        userDefaults.set(isAutoSaveEnabled, forKey: "autoSave")
        userDefaults.set(autoSaveInterval, forKey: "autoSaveInterval")
        userDefaults.set(isMinimapVisible, forKey: "minimap")
        userDefaults.set(isIndentGuidesVisible, forKey: "indentGuides")
        userDefaults.set(isOccurrenceHighlightEnabled, forKey: "occurrenceHighlight")
        userDefaults.set(appLanguage.rawValue, forKey: "appLanguage")

        if let data = try? JSONEncoder().encode(recentFiles) {
            userDefaults.set(data, forKey: recentFilesKey)
        }
    }

    func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        saveSettings()
    }

    func clearRecentFiles() {
        recentFiles.removeAll()
        saveSettings()
    }
}

/// Application theme options
enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return String(localized: "system")
        case .light: return String(localized: "light")
        case .dark: return String(localized: "dark")
        }
    }
}

/// Application language options
enum AppLanguage: String, CaseIterable {
    case system = "System"
    case english = "English"
    case chinese = "Chinese"
    case hindi = "Hindi"
    case spanish = "Spanish"
    case french = "French"
    case arabic = "Arabic"
    case bengali = "Bengali"
    case portuguese = "Portuguese"
    case russian = "Russian"
    case japanese = "Japanese"
    case german = "German"
    case korean = "Korean"
    case vietnamese = "Vietnamese"
    case turkish = "Turkish"
    case italian = "Italian"
    case thai = "Thai"
    case polish = "Polish"
    case dutch = "Dutch"
    case indonesian = "Indonesian"
    case ukrainian = "Ukrainian"

    var code: String {
        switch self {
        case .system: return ""
        case .english: return "en"
        case .chinese: return "zh-Hans"
        case .hindi: return "hi"
        case .spanish: return "es"
        case .french: return "fr"
        case .arabic: return "ar"
        case .bengali: return "bn"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .japanese: return "ja"
        case .german: return "de"
        case .korean: return "ko"
        case .vietnamese: return "vi"
        case .turkish: return "tr"
        case .italian: return "it"
        case .thai: return "th"
        case .polish: return "pl"
        case .dutch: return "nl"
        case .indonesian: return "id"
        case .ukrainian: return "uk"
        }
    }

    var displayName: String {
        switch self {
        case .system: return String(localized: "lang.system")
        case .english: return "English"
        case .chinese: return "简体中文"
        case .hindi: return "हिन्दी"
        case .spanish: return "Español"
        case .french: return "Français"
        case .arabic: return "العربية"
        case .bengali: return "বাংলা"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .japanese: return "日本語"
        case .german: return "Deutsch"
        case .korean: return "한국어"
        case .vietnamese: return "Tiếng Việt"
        case .turkish: return "Türkçe"
        case .italian: return "Italiano"
        case .thai: return "ไทย"
        case .polish: return "Polski"
        case .dutch: return "Nederlands"
        case .indonesian: return "Bahasa Indonesia"
        case .ukrainian: return "Українська"
        }
    }
}
