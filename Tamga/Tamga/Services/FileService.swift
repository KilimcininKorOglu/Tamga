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

// MARK: - File Change Monitor

/// Watches a set of file URLs and reports when any of them changes on disk.
///
/// Each URL gets a `DispatchSource` vnode watcher. An atomic save replaces the file's
/// inode, so the watcher re-arms itself after every event; the caller compares content
/// to ignore a change the app made itself.
@MainActor
final class FileChangeMonitor: ObservableObject {
    /// Called on the main queue with the URL whose file changed.
    var onChange: ((URL) -> Void)?

    private var sources: [URL: DispatchSourceFileSystemObject] = [:]

    /// Starts watching any new URL and stops watching any dropped URL, so the watched
    /// set always mirrors the open file-backed tabs.
    func sync(with urls: Set<URL>) {
        for url in sources.keys where !urls.contains(url) {
            unwatch(url)
        }
        for url in urls where sources[url] == nil {
            watch(url)
        }
    }

    private func watch(_ url: URL) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.onChange?(url)
            self.rearm(url)
        }
        source.setCancelHandler { close(descriptor) }
        sources[url] = source
        source.resume()
    }

    /// Re-opens the watch after an event, because an atomic save leaves the old
    /// descriptor pointing at a replaced inode that never fires again.
    private func rearm(_ url: URL) {
        guard sources[url] != nil else { return }
        unwatch(url)
        if FileManager.default.fileExists(atPath: url.path) {
            watch(url)
        }
    }

    private func unwatch(_ url: URL) {
        sources[url]?.cancel()
        sources[url] = nil
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
