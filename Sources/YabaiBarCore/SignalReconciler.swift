import Foundation

public struct SignalDefinition: Equatable, Sendable {
    public let event: String
    public var label: String { "yabai-bar.\(event.replacingOccurrences(of: "_", with: "-"))" }

    public init(event: String) {
        self.event = event
    }
}

public actor SignalReconciler {
    public static let definitions = [
        "space_changed", "space_created", "space_destroyed",
        "display_added", "display_removed", "display_moved", "display_resized", "display_changed",
        "system_woke", "dock_did_restart",
    ].map(SignalDefinition.init)

    private let client: YabaiClient
    private let helperPath: String

    public init(client: YabaiClient, helperPath: String) {
        self.client = client
        self.helperPath = helperPath
    }

    public func reconcile() async throws {
        let current = try await client.signals()
        let owned = current.filter { $0.label.hasPrefix("yabai-bar.") }
        for signal in owned {
            try await client.removeSignal(label: signal.label)
        }
        for definition in Self.definitions {
            try await client.addSignal(
                event: definition.event,
                label: definition.label,
                action: "\(Self.shellQuote(helperPath)) event \(Self.shellQuote(definition.event))"
            )
        }
    }

    public func removeOwnedSignals() async {
        guard let signals = try? await client.signals() else { return }
        for signal in signals where signal.label.hasPrefix("yabai-bar.") {
            try? await client.removeSignal(label: signal.label)
        }
    }

    public func isHealthy() async -> Bool {
        guard let signals = try? await client.signals() else { return false }
        let ownedLabels = Set(signals.lazy.filter { $0.label.hasPrefix("yabai-bar.") }.map(\.label))
        return Self.definitions.allSatisfy { ownedLabels.contains($0.label) }
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
