import Foundation

public enum IPCCommand: Codable, Equatable, Sendable {
    case event(String)
    case refresh
    case status

    enum CodingKeys: String, CodingKey { case command, event }
    enum Command: String, Codable { case event, refresh, status }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Command.self, forKey: .command) {
        case .event:
            self = .event(try container.decode(String.self, forKey: .event))
        case .refresh:
            self = .refresh
        case .status:
            self = .status
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .event(let event):
            try container.encode(Command.event, forKey: .command)
            try container.encode(event, forKey: .event)
        case .refresh:
            try container.encode(Command.refresh, forKey: .command)
        case .status:
            try container.encode(Command.status, forKey: .command)
        }
    }
}

public struct IPCResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let message: String?
    public let diagnostics: DiagnosticsSnapshot?

    public init(ok: Bool, message: String? = nil, diagnostics: DiagnosticsSnapshot? = nil) {
        self.ok = ok
        self.message = message
        self.diagnostics = diagnostics
    }
}

public enum IPCPaths {
    public static func socketURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory.appendingPathComponent("Library/Application Support/YabaiBar/yabai-bar.sock")
    }
}
