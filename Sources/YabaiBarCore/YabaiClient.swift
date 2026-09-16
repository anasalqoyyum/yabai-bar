import Foundation

public enum YabaiClientError: LocalizedError, Equatable {
    case executableNotFound
    case malformedVersion(String)
    case unsupportedVersion(SemanticVersion)
    case invalidResponse(String)
    case commandFailed(arguments: [String], message: String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "The yabai executable was not found."
        case .malformedVersion(let output):
            return "Yabai returned an unreadable version: \(output)"
        case .unsupportedVersion(let version):
            return "Yabai \(version) is too old. Version 7.1.19 or newer is required."
        case .invalidResponse(let message):
            return "Yabai returned invalid data: \(message)"
        case .commandFailed(_, let message):
            return message
        }
    }
}

public actor YabaiClient {
    public static let minimumVersion = SemanticVersion(major: 7, minor: 1, patch: 19)

    private let runner: any ProcessRunning
    private var executableURL: URL?

    public init(executableURL: URL? = nil, runner: any ProcessRunning = ProcessRunner()) {
        self.executableURL = executableURL
        self.runner = runner
    }

    public func setExecutableURL(_ url: URL?) {
        executableURL = url
    }

    public func resolvedExecutableURL() -> URL? { executableURL }

    public func version() async throws -> SemanticVersion {
        let result = try await execute(["--version"])
        guard let version = SemanticVersion(result.standardOutput + " " + result.standardError) else {
            throw YabaiClientError.malformedVersion(result.standardOutput + result.standardError)
        }
        return version
    }

    public func checkSupportedVersion() async throws -> SemanticVersion {
        let version = try await version()
        guard version >= Self.minimumVersion else { throw YabaiClientError.unsupportedVersion(version) }
        return version
    }

    public func spaces() async throws -> [YabaiSpace] {
        let result = try await execute(["-m", "query", "--spaces"])
        do {
            return try JSONDecoder().decode([YabaiSpace].self, from: Data(result.standardOutput.utf8))
                .sorted { $0.index < $1.index }
        } catch {
            throw YabaiClientError.invalidResponse(error.localizedDescription)
        }
    }

    public func focusSpace(index: Int) async throws {
        do {
            _ = try await execute(["-m", "space", "--focus", String(index)])
        } catch YabaiClientError.commandFailed(_, let message) where Self.isAlreadyFocusedMessage(message) {
            return
        }
    }

    public func focusSpace(index: Int, currentFocusedSpaceIndex: Int?) async throws {
        guard currentFocusedSpaceIndex != index else { return }
        try await focusSpace(index: index)
    }

    public func signals() async throws -> [YabaiSignal] {
        let result = try await execute(["-m", "signal", "--list"])
        do {
            return try JSONDecoder().decode([YabaiSignal].self, from: Data(result.standardOutput.utf8))
        } catch {
            throw YabaiClientError.invalidResponse(error.localizedDescription)
        }
    }

    public func addSignal(event: String, label: String, action: String) async throws {
        _ = try await execute([
            "-m", "signal", "--add",
            "event=\(event)", "label=\(label)", "action=\(action)",
        ])
    }

    public func removeSignal(label: String) async throws {
        _ = try await execute(["-m", "signal", "--remove", label])
    }

    public static func isAlreadyFocusedMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("already focused")
            || normalized.contains("same space")
            || normalized.contains("cannot focus space due to an equal space")
    }

    private func execute(_ arguments: [String]) async throws -> ProcessResult {
        guard let executableURL else { throw YabaiClientError.executableNotFound }
        let result = try await runner.run(executableURL: executableURL, arguments: arguments)
        guard result.exitCode == 0 else {
            let message = [result.standardError, result.standardOutput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? "Yabai exited with status \(result.exitCode)."
            throw YabaiClientError.commandFailed(arguments: arguments, message: message)
        }
        return result
    }
}
