import Foundation

public struct YabaiSpace: Codable, Identifiable, Equatable, Sendable {
    public let id: UInt64
    public let index: Int
    public let label: String
    public let display: Int
    public let hasFocus: Bool
    public let isVisible: Bool
    public let isNativeFullscreen: Bool
    public let windows: [Int]

    public var isOccupied: Bool { !windows.isEmpty }

    public init(
        id: UInt64,
        index: Int,
        label: String,
        display: Int,
        hasFocus: Bool,
        isVisible: Bool,
        isNativeFullscreen: Bool,
        windows: [Int] = []
    ) {
        self.id = id
        self.index = index
        self.label = label
        self.display = display
        self.hasFocus = hasFocus
        self.isVisible = isVisible
        self.isNativeFullscreen = isNativeFullscreen
        self.windows = windows
    }

    enum CodingKeys: String, CodingKey {
        case id, index, label, display, windows
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
        case isNativeFullscreen = "is-native-fullscreen"
    }
}

public struct YabaiSignal: Codable, Equatable, Sendable {
    public let index: Int?
    public let label: String
    public let event: String
    public let action: String

    public init(index: Int? = nil, label: String, event: String, action: String) {
        self.index = index
        self.label = label
        self.event = event
        self.action = action
    }
}

public struct SemanticVersion: Comparable, Codable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ rawValue: String) {
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { !$0.isNumber && $0 != "." })
            .first(where: { $0.contains(".") })
        guard let candidate else { return nil }
        let components = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else { return nil }
        self.init(major: major, minor: minor, patch: components.count > 2 ? Int(components[2]) ?? 0 : 0)
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

public enum SIPStatus: String, Codable, Sendable {
    case enabled
    case disabled
    case partiallyDisabled = "partially-disabled"
    case unknown

    public init(output: String) {
        let normalized = output.lowercased()
        if normalized.contains("enabled") && normalized.contains("custom configuration") {
            self = .partiallyDisabled
        } else if normalized.contains("disabled") {
            self = .disabled
        } else if normalized.contains("enabled") {
            self = .enabled
        } else {
            self = .unknown
        }
    }
}

public enum YabaiAvailability: String, Codable, Sendable {
    case supported
    case unsupportedOldVersion = "unsupported-old-version"
    case notInstalled = "not-installed"
    case notRunning = "not-running"
}

public enum SpaceFocusSupport {
    public static let lastKnownBrokenMacOS27Version = SemanticVersion(major: 7, minor: 1, patch: 25)

    public static func isAvailable(
        operatingSystemVersion: OperatingSystemVersion,
        sipStatus: SIPStatus,
        yabaiVersion: SemanticVersion
    ) -> Bool {
        !(operatingSystemVersion.majorVersion == 27
            && sipStatus == .enabled
            && yabaiVersion <= lastKnownBrokenMacOS27Version)
    }
}

public struct DiagnosticsSnapshot: Codable, Equatable, Sendable {
    public var availability: YabaiAvailability
    public var yabaiPath: String?
    public var version: SemanticVersion?
    public var sipStatus: SIPStatus
    public var spaceCount: Int
    public var displayCount: Int
    public var signalBridgeHealthy: Bool
    public var spaceFocusAvailable: Bool
    public var lastError: String?

    public init(
        availability: YabaiAvailability = .notRunning,
        yabaiPath: String? = nil,
        version: SemanticVersion? = nil,
        sipStatus: SIPStatus = .unknown,
        spaceCount: Int = 0,
        displayCount: Int = 0,
        signalBridgeHealthy: Bool = false,
        spaceFocusAvailable: Bool = false,
        lastError: String? = nil
    ) {
        self.availability = availability
        self.yabaiPath = yabaiPath
        self.version = version
        self.sipStatus = sipStatus
        self.spaceCount = spaceCount
        self.displayCount = displayCount
        self.signalBridgeHealthy = signalBridgeHealthy
        self.spaceFocusAvailable = spaceFocusAvailable
        self.lastError = lastError
    }
}
