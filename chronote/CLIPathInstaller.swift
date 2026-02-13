import Foundation

enum CLIPathInstaller {
    static let commandName = "chronote-cli"
    static let targetURL = URL(fileURLWithPath: "/usr/local/bin/chronote-cli")

    static func embeddedCLIURL() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let cliURL = resourceURL.appendingPathComponent(commandName)
        let path = cliURL.path
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
        return cliURL
    }

    static func isInstalledInPath() -> Bool {
        let path = targetURL.path
        guard FileManager.default.fileExists(atPath: path) else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    static func installSymlinkToPath() throws {
        guard let sourceURL = embeddedCLIURL() else {
            throw CLIPathInstallError.cliNotEmbedded
        }

        let fileManager = FileManager.default
        let binDir = targetURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        } catch {
            throw CLIPathInstallError.permissionDenied(manualCommand(for: sourceURL))
        }

        if fileManager.fileExists(atPath: targetURL.path) {
            do {
                try fileManager.removeItem(at: targetURL)
            } catch {
                throw CLIPathInstallError.permissionDenied(manualCommand(for: sourceURL))
            }
        }

        do {
            try fileManager.createSymbolicLink(at: targetURL, withDestinationURL: sourceURL)
        } catch {
            throw CLIPathInstallError.permissionDenied(manualCommand(for: sourceURL))
        }
    }

    private static func manualCommand(for sourceURL: URL) -> String {
        let source = shellEscape(sourceURL.path)
        return "sudo mkdir -p /usr/local/bin && sudo ln -sf \(source) /usr/local/bin/chronote-cli"
    }

    private static func shellEscape(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum CLIPathInstallError: LocalizedError {
    case cliNotEmbedded
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .cliNotEmbedded:
            return "Embedded chronote-cli not found in app bundle Resources."
        case .permissionDenied(let command):
            return """
            Cannot write /usr/local/bin from app sandbox.
            Run this command manually in Terminal:
            \(command)
            """
        }
    }
}
