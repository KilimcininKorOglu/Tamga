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
