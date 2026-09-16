import Foundation

public struct SIPDetector: Sendable {
    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning = ProcessRunner()) {
        self.runner = runner
    }

    public func status() async -> SIPStatus {
        guard let result = try? await runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/csrutil"),
            arguments: ["status"]
        ) else { return .unknown }
        return SIPStatus(output: result.standardOutput + result.standardError)
    }
}
