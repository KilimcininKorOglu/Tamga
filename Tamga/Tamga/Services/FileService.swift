import Foundation
import UniformTypeIdentifiers

/// Service for file read/write operations
class FileService {
    static let shared = FileService()

    private init() {}

    // MARK: - Read Operations

    func readFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let encoding = FileEncoding.detect(from: data)

        guard let content = String(data: data, encoding: encoding.encoding) else {
            throw FileServiceError.decodingFailed
        }

        return content
    }

    // MARK: - Write Operations

    func writeFile(content: String, to url: URL, encoding: FileEncoding = .utf8) throws {
        guard let data = content.data(using: encoding.encoding) else {
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
