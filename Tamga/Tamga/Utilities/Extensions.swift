import Foundation

// MARK: - String Extensions

extension String {
    /// Returns the number of lines in the string
    var lineCount: Int {
        isEmpty ? 1 : components(separatedBy: .newlines).count
    }

    /// Returns the number of words in the string
    var wordCount: Int {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

// MARK: - Notification.Name Extensions

extension Notification.Name {
    static let duplicateLine = Notification.Name("duplicateLine")
    static let moveLineUp = Notification.Name("moveLineUp")
    static let moveLineDown = Notification.Name("moveLineDown")
    static let sortLinesAscending = Notification.Name("sortLinesAscending")
    static let sortLinesDescending = Notification.Name("sortLinesDescending")
    static let removeDuplicateLines = Notification.Name("removeDuplicateLines")
    static let uppercaseSelection = Notification.Name("uppercaseSelection")
    static let lowercaseSelection = Notification.Name("lowercaseSelection")
    static let capitalizeSelection = Notification.Name("capitalizeSelection")
    static let formatJSON = Notification.Name("formatJSON")
    static let minifyJSON = Notification.Name("minifyJSON")
    static let autoSave = Notification.Name("autoSave")
    static let foldCode = Notification.Name("foldCode")
    static let unfoldCode = Notification.Name("unfoldCode")
    static let foldAll = Notification.Name("foldAll")
    static let unfoldAll = Notification.Name("unfoldAll")
}
