import Foundation

enum CLIPathInstaller {
    static let commandName = "chronote-cli"
    static let targetURL = URL(fileURLWithPath: "/usr/local/bin/chronote-cli")
    private static let commonBinaryDirectories = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    static func resolvedPathInEnvironmentPath() -> String? {
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let fileManager = FileManager.default
        let candidates = pathEnv
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }

        for directory in candidates {
            let commandPath = URL(fileURLWithPath: directory).appendingPathComponent(commandName).path
            if fileManager.isExecutableFile(atPath: commandPath) {
                return commandPath
            }
        }

        return nil
    }

    static func resolvedPathInCommonDirectories() -> String? {
        let fileManager = FileManager.default
        for directory in commonBinaryDirectories {
            let commandPath = URL(fileURLWithPath: directory).appendingPathComponent(commandName).path
            if fileManager.isExecutableFile(atPath: commandPath) {
                return commandPath
            }
        }
        return nil
    }

    static func resolvedPathFromWhereis() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/whereis")
        process.arguments = [commandName]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            let parts = output
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .dropFirst()
                .map(String.init)
            for candidate in parts {
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    static func resolvedCLIPath() -> String? {
        resolvedPathInEnvironmentPath()
            ?? resolvedPathInCommonDirectories()
            ?? resolvedPathFromWhereis()
    }

    static func embeddedCLIURL() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let cliURL = resourceURL.appendingPathComponent(commandName)
        let path = cliURL.path
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
        return cliURL
    }

    static func isInstalledInPath() -> Bool {
        resolvedCLIPath() != nil
    }

    static func manualInstallCommandForEmbeddedCLI() -> String? {
        guard let sourceURL = embeddedCLIURL() else { return nil }
        return manualCommand(for: sourceURL)
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
