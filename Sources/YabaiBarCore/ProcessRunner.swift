import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String = "", standardError: String = "") {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public protocol ProcessRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult
}

public enum ProcessRunnerError: LocalizedError {
    case couldNotLaunch(String)

    public var errorDescription: String? {
        switch self {
        case .couldNotLaunch(let message): return message
        }
    }
}

public struct ProcessRunner: ProcessRunning {
    public init() {}

    public func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.terminationHandler = { process in
                let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    standardOutput: String(decoding: output, as: UTF8.self),
                    standardError: String(decoding: error, as: UTF8.self)
                ))
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: ProcessRunnerError.couldNotLaunch(error.localizedDescription))
            }
        }
    }
}
