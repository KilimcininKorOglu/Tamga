import Foundation

/// Application constants
enum Constants {
    /// App information
    enum App {
        static let name = "Tamga"
        static let bundleId = "com.tamga.app"
        static let version = "1.0.0"
        static let minMacOSVersion = "13.0"
    }

    /// Author credit shown in the about panel
    enum Author {
        static let name = "Abdullah Kerem Gök"
        static let handle = "x.com/KorOglan"
        static let profileURL = "https://x.com/KorOglan"
    }

    /// Default values
    enum Defaults {
        static let fontSize: CGFloat = 14
        static let fontName = "SF Mono"
        static let tabWidth = 4
        static let maxRecentFiles = 10
        /// Quiet period after the last edit before a crash-safety session save fires.
        static let sessionAutosaveDebounceInterval: TimeInterval = 2.0
    }

    /// File paths
    enum Paths {
        static let applicationSupport = "Tamga"
        static let sessionFile = "session.json"
        static let settingsFile = "settings.json"
        static let tempFolder = "temp"
    }

    /// Supported file extensions
    enum FileExtensions {
        static let text = ["txt", "text", "md", "markdown"]
        static let code = ["swift", "py", "js", "ts", "jsx", "tsx", "json", "html", "css", "xml", "sql", "sh", "bash", "zsh", "yml", "yaml"]
        static let all = text + code
    }

    /// Keyboard shortcuts
    enum Shortcuts {
        static let newTab = "n"
        static let open = "o"
        static let save = "s"
        static let closeTab = "w"
        static let find = "f"
        static let findNext = "g"
    }

    /// UI dimensions
    enum UI {
        static let minWindowWidth: CGFloat = 600
        static let minWindowHeight: CGFloat = 400
        static let tabBarHeight: CGFloat = 36
        static let statusBarHeight: CGFloat = 24
        static let lineNumberWidth: CGFloat = 50
    }
}
