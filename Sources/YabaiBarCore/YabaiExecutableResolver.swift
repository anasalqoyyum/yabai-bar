import Foundation

public struct YabaiExecutableResolver: Sendable {
    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning = ProcessRunner()) {
        self.runner = runner
    }

    public func resolve(configuredPath: String) async -> URL? {
        if configuredPath != "auto" && !configuredPath.isEmpty {
            return executable(at: configuredPath)
        }

        for path in ["/opt/homebrew/bin/yabai", "/usr/local/bin/yabai"] {
            if let url = executable(at: path) { return url }
        }

        guard let result = try? await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-l", "-c", "command -v yabai"]
        ), result.exitCode == 0 else { return nil }
        return executable(at: result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func executable(at path: String) -> URL? {
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
