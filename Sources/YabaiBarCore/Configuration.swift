import Foundation

public enum SpaceDisplayMode: String, Codable, CaseIterable, Sendable {
    case index
    case label
    case labelOrIndex = "label-or-index"
}

public enum ActiveIndicatorStyle: String, Codable, CaseIterable, Sendable {
    case pill
    case underline
    case bold
}

public enum SpaceSpacing: String, Codable, CaseIterable, Sendable {
    case compact
    case regular
    case relaxed

    public var points: Double {
        switch self {
        case .compact: return 4
        case .regular: return 7
        case .relaxed: return 10
        }
    }
}

public enum BarFont: String, Codable, CaseIterable, Sendable {
    case system
    case monospaced
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var yabaiPath: String
    public var spaceDisplay: SpaceDisplayMode
    public var activeStyle: ActiveIndicatorStyle
    public var showVisibleSpaces: Bool
    public var showEmptySpaces: Bool
    public var launchAtLogin: Bool
    public var spacing: SpaceSpacing
    public var font: BarFont

    public init(
        yabaiPath: String = "auto",
        spaceDisplay: SpaceDisplayMode = .index,
        activeStyle: ActiveIndicatorStyle = .pill,
        showVisibleSpaces: Bool = true,
        showEmptySpaces: Bool = true,
        launchAtLogin: Bool = true,
        spacing: SpaceSpacing = .regular,
        font: BarFont = .system
    ) {
        self.yabaiPath = yabaiPath
        self.spaceDisplay = spaceDisplay
        self.activeStyle = activeStyle
        self.showVisibleSpaces = showVisibleSpaces
        self.showEmptySpaces = showEmptySpaces
        self.launchAtLogin = launchAtLogin
        self.spacing = spacing
        self.font = font
    }

    public func title(for space: YabaiSpace) -> String {
        switch spaceDisplay {
        case .index:
            return String(space.index)
        case .label:
            return space.label
        case .labelOrIndex:
            return space.label.isEmpty ? String(space.index) : space.label
        }
    }

    public func displayedSpaces(from spaces: [YabaiSpace]) -> [YabaiSpace] {
        spaces
            .filter { showEmptySpaces || !$0.windows.isEmpty || $0.hasFocus || $0.isVisible }
            .sorted { $0.index < $1.index }
    }

    enum CodingKeys: String, CodingKey {
        case yabaiPath, spaceDisplay, activeStyle, showVisibleSpaces, showEmptySpaces
        case launchAtLogin, spacing, font
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        yabaiPath = try container.decodeIfPresent(String.self, forKey: .yabaiPath) ?? "auto"
        spaceDisplay = try container.decodeIfPresent(SpaceDisplayMode.self, forKey: .spaceDisplay) ?? .index
        activeStyle = try container.decodeIfPresent(ActiveIndicatorStyle.self, forKey: .activeStyle) ?? .pill
        showVisibleSpaces = try container.decodeIfPresent(Bool.self, forKey: .showVisibleSpaces) ?? true
        showEmptySpaces = try container.decodeIfPresent(Bool.self, forKey: .showEmptySpaces) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        spacing = try container.decodeIfPresent(SpaceSpacing.self, forKey: .spacing) ?? .regular
        font = try container.decodeIfPresent(BarFont.self, forKey: .font) ?? .system
    }
}

public struct ConfigurationFile {
    public let url: URL

    public init(url: URL = Self.defaultURL()) {
        self.url = url
    }

    public static func defaultURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory.appendingPathComponent(".config/yabai-bar/config.json")
    }

    public func load() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppConfiguration() }
        return try JSONDecoder().decode(AppConfiguration.self, from: Data(contentsOf: url))
    }

    public func save(_ configuration: AppConfiguration) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(configuration).write(to: url, options: .atomic)
    }
}
