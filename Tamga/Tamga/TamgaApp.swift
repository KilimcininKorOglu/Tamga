import SwiftUI

@main
struct TamgaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            TamgaCommands()
        }

        // Adds the standard "Settings…" (Cmd+,) item to the app menu.
        Settings {
            SettingsView()
                .preferredColorScheme(appState.currentTheme.colorScheme)
        }
    }
}

// MARK: - Font Panel

/// Bridges the system font panel to `AppState`. Retained by `shared` because
/// `NSFontManager.target` is weak, and it writes the chosen font through so the change
/// persists.
@MainActor
final class FontPanelController: NSObject {
    static let shared = FontPanelController()
    private override init() { super.init() }

    private var currentFont: NSFont {
        NSFont(name: AppState.shared.fontName, size: AppState.shared.fontSize)
            ?? .monospacedSystemFont(ofSize: AppState.shared.fontSize, weight: .regular)
    }

    func show() {
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(changeFont(_:))
        manager.setSelectedFont(currentFont, isMultiple: false)
        manager.orderFrontFontPanel(nil)
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let sender else { return }
        let newFont = sender.convert(currentFont)
        AppState.shared.fontName = newFont.fontName
        AppState.shared.fontSize = newFont.pointSize
        AppState.shared.saveSettings()
    }
}

// MARK: - Settings

/// Preferences window collecting the editor and general options that were previously
/// only reachable through scattered menu toggles.
struct SettingsView: View {
    @ObservedObject private var appState = AppState.shared

    private static let fontOptions = [
        "SF Mono", "Menlo", "Monaco", "Courier New",
        "Fira Code", "JetBrains Mono", "Source Code Pro"
    ]

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(String(localized: "preferences.general"), systemImage: "gearshape") }
            editorTab
                .tabItem { Label(String(localized: "preferences.editor"), systemImage: "textformat") }
        }
        .frame(width: 420, height: 320)
    }

    private var generalTab: some View {
        Form {
            Picker(String(localized: "theme"), selection: bind(\.currentTheme)) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }

            Picker(String(localized: "language"), selection: languageBinding) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }

            Toggle(String(localized: "auto.save"), isOn: bind(\.isAutoSaveEnabled))
        }
        .padding()
    }

    private var editorTab: some View {
        Form {
            Picker(String(localized: "font"), selection: bind(\.fontName)) {
                ForEach(Self.fontOptions, id: \.self) { name in
                    Text(name).tag(name)
                }
            }

            Stepper(value: bind(\.fontSize), in: 8...48, step: 1) {
                Text("\(String(localized: "font.size")): \(Int(appState.fontSize))")
            }

            Button(String(localized: "choose.font")) {
                FontPanelController.shared.show()
            }

            Toggle(String(localized: "line.numbers"), isOn: bind(\.showLineNumbers))
            Toggle(String(localized: "word.wrap"), isOn: bind(\.isWordWrapEnabled))
            Toggle(String(localized: "show.invisibles"), isOn: bind(\.showInvisibleCharacters))
            Toggle(String(localized: "status.bar"), isOn: bind(\.isStatusBarVisible))
            Toggle(String(localized: "sidebar"), isOn: bind(\.isSidebarVisible))
        }
        .padding()
    }

    /// A write-through binding that persists the change, so a preference set here survives
    /// relaunch instead of living only in memory like the menu toggles did.
    private func bind<T>(_ keyPath: ReferenceWritableKeyPath<AppState, T>) -> Binding<T> {
        Binding(
            get: { appState[keyPath: keyPath] },
            set: { newValue in
                appState[keyPath: keyPath] = newValue
                appState.saveSettings()
            }
        )
    }

    /// Language is special: it triggers a relaunch, so it routes through `setLanguage`.
    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { appState.appLanguage },
            set: { newValue in
                guard newValue != appState.appLanguage else { return }
                appState.setLanguage(newValue)
            }
        )
    }
}

// MARK: - CLI Processing

/// Stores CLI file paths to be opened after session restore
enum CLIFileQueue {
    static var pendingFiles: [String] = []
}

private func processCommandLineArguments() {
    let args = CommandLine.arguments

    // The first argument is the app path; the rest are file paths
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
