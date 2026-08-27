import AppKit
import Foundation
import SwiftUI

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

    /// Truncates the string to the specified length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count <= length {
            return self
        }
        return String(prefix(length)) + trailing
    }
}

// MARK: - URL Extensions

extension URL {
    /// Returns the file extension without the dot
    var fileExtension: String {
        pathExtension.lowercased()
    }

    /// Checks if the URL points to a text file
    var isTextFile: Bool {
        let textExtensions = Constants.FileExtensions.all
        return textExtensions.contains(fileExtension)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a conditional modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a modifier only on macOS
    @ViewBuilder
    func macOS<Transform: View>(_ transform: (Self) -> Transform) -> some View {
        #if os(macOS)
            transform(self)
        #else
            self
        #endif
    }
}

// MARK: - Color Extensions

extension Color {
    /// Creates a color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - NSColor Extensions

extension NSColor {
    /// Creates an NSColor from hex string
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Date Extensions

extension Date {
    /// Returns a formatted string for display
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Returns a relative time string (e.g., "2 hours ago")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Array Extensions

extension Array where Element: Equatable {
    /// Moves an element from one index to another
    mutating func move(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex,
            oldIndex >= 0, oldIndex < count,
            newIndex >= 0, newIndex < count
        else { return }

        let element = remove(at: oldIndex)
        insert(element, at: newIndex)
    }
}

// MARK: - Binding Extensions

extension Binding {
    /// Creates a binding that triggers an action on change
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
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
    static let openFileFromCLI = Notification.Name("openFileFromCLI")
}
