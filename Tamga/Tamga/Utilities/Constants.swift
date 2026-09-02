import Foundation

/// Application constants
enum Constants {
    /// Author credit shown in the about panel
    enum Author {
        static let name = "Abdullah Kerem Gök"
        static let handle = "x.com/KorOglan"
        static let profileURL = "https://x.com/KorOglan"
    }

    /// Default values
    enum Defaults {
        /// Quiet period after the last edit before a crash-safety session save fires.
        static let sessionAutosaveDebounceInterval: TimeInterval = 2.0
    }

    /// Supported file extensions
    enum FileExtensions {
        static let text = ["txt", "text", "md", "markdown"]
        static let code = ["swift", "py", "js", "ts", "jsx", "tsx", "json", "html", "css", "xml", "sql", "sh", "bash", "zsh", "yml", "yaml"]
        static let all = text + code
    }
}
