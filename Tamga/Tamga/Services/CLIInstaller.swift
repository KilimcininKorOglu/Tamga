import AppKit
import Foundation

/// Installs the `tamga` command line launcher into /usr/local/bin.
///
/// The copy needs administrator privileges, so every write goes through osascript.
enum CLIInstaller {
    /// Launcher written to /usr/local/bin/tamga. It forwards every argument to the
    /// app as an absolute path, because the app is opened out of the caller's
    /// working directory.
    private static let launcherScript = """
        #!/bin/bash
        # Tamga CLI - opens files from the terminal

        APP_PATH="/Applications/Tamga.app"

        if [ $# -eq 0 ]; then
            # No arguments: just launch the app
            open "$APP_PATH"
            exit 0
        fi

        # Resolve every argument to an absolute path
        args=()
        for file in "$@"; do
            if [[ "$file" = /* ]]; then
                args+=("$file")
            else
                args+=("$(pwd)/$file")
            fi
        done

        open "$APP_PATH" --args "${args[@]}"
        """

    /// Asks for confirmation, then installs the launcher and reports the outcome.
    static func install() {
        let alert = NSAlert()
        alert.messageText = String(localized: "install.cli.title")
        alert.informativeText = String(localized: "install.cli.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "install"))
        alert.addButton(withTitle: String(localized: "cancel"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try writeLauncher()
            showAlert(
                title: String(localized: "install.cli.success.title"),
                message: String(localized: "install.cli.success.message"),
                style: .informational
            )
        } catch {
            showAlert(
                title: String(localized: "install.cli.error.title"),
                message: error.localizedDescription,
                style: .critical
            )
        }
    }

    /// Copies the launcher into /usr/local/bin with administrator privileges,
    /// creating the directory first when the system does not ship it.
    private static func writeLauncher() throws {
        let fileManager = FileManager.default
        let binPath = "/usr/local/bin"
        let destinationPath = "\(binPath)/tamga"

        if !fileManager.fileExists(atPath: binPath) {
            try runAsAdministrator("mkdir -p \(shellQuote(binPath))")
        }

        let tempPath = NSTemporaryDirectory() + "tamga-cli.sh"
        try launcherScript.write(toFile: tempPath, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(atPath: tempPath) }

        try runAsAdministrator(
            "cp \(shellQuote(tempPath)) \(shellQuote(destinationPath)) "
                + "&& chmod +x \(shellQuote(destinationPath))"
        )
    }

    private static func runAsAdministrator(_ shellCommand: String) throws {
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        let appleScript = "do shell script \(appleScriptString(shellCommand)) with administrator privileges"
        process.arguments = ["-e", appleScript]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        // A cancelled password prompt or a failed command exits non-zero. Surface it
        // as an error so install() does not report a success that never happened.
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw CLIInstallerError.commandFailed(detail)
        }
    }

    /// Wraps a string in single quotes so the shell treats it as one literal word,
    /// escaping any embedded single quote. Prevents path text from breaking the command.
    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Encodes a string as an AppleScript string literal, escaping backslashes and
    /// double quotes so the shell command cannot break out of the `do shell script` argument.
    private static func appleScriptString(_ value: String) -> String {
        let escaped =
            value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Failure of the privileged install command, carrying the osascript error text.
    private enum CLIInstallerError: LocalizedError {
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .commandFailed(let detail):
                return detail.isEmpty ? String(localized: "install.cli.error.title") : detail
            }
        }
    }

    private static func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
