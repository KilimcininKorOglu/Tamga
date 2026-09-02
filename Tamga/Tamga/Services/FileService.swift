import Foundation
import UniformTypeIdentifiers

/// Service for file read/write operations
class FileService {
    static let shared = FileService()

    private init() {}

    // MARK: - Read Operations

    func readFile(at url: URL) throws -> String {
        try readFileWithLineEnding(at: url).content
    }

    /// Reads a file, returning its content normalized to `\n` plus the line-ending style
    /// it used on disk. Detection runs before normalization, so the original style is
    /// preserved for the status bar and for the next save.
    func readFileWithLineEnding(at url: URL) throws -> (content: String, lineEnding: LineEnding) {
        let data = try Data(contentsOf: url)
        let encoding = FileEncoding.detect(from: data)

        guard let raw = String(data: data, encoding: encoding.encoding) else {
            throw FileServiceError.decodingFailed
        }

        let lineEnding = LineEnding.detect(from: raw)
        return (Self.normalizeToLF(raw), lineEnding)
    }

    /// Collapses `\r\n` and lone `\r` to `\n`, so the editor and the gutter only ever
    /// see one separator regardless of the file's original style.
    private static func normalizeToLF(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: - Write Operations

    func writeFile(
        content: String,
        to url: URL,
        encoding: FileEncoding = .utf8,
        lineEnding: LineEnding = .lf
    ) throws {
        // Content is held with `\n`; convert to the target style only on write.
        let output =
            lineEnding == .lf
            ? content
            : content.replacingOccurrences(of: "\n", with: lineEnding.sequence)

        guard let data = output.data(using: encoding.encoding) else {
            throw FileServiceError.encodingFailed
        }

        try data.write(to: url, options: .atomic)
    }

}

// MARK: - Errors

enum FileServiceError: LocalizedError {
    case decodingFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .decodingFailed:
            return String(localized: "error.decoding.failed")
        case .encodingFailed:
            return String(localized: "error.encoding.failed")
        }
    }
}
