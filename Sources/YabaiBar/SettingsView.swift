import AppKit
import SwiftUI
import YabaiBarCore

enum SettingsTab: Hashable {
    case general
    case appearance
    case diagnostics
}

@MainActor
final class SettingsWindowController: NSWindowController {
    private let model: AppModel
    private let selection = SettingsSelection()

    init(model: AppModel) {
        self.model = model
        let content = SettingsView(model: model, selection: selection)
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.title = "Yabai Bar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 540, height: 390))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func show(tab: SettingsTab) {
        selection.tab = tab
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class SettingsSelection: ObservableObject {
    @Published var tab: SettingsTab = .general
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var selection: SettingsSelection
    @State private var draft: AppConfiguration

    init(model: AppModel, selection: SettingsSelection) {
        self.model = model
        self.selection = selection
        _draft = State(initialValue: model.configuration)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection.tab) {
                general.tag(SettingsTab.general).tabItem { Label("General", systemImage: "gearshape") }
                appearance.tag(SettingsTab.appearance).tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }
                diagnostics.tag(SettingsTab.diagnostics).tabItem { Label("Diagnostics", systemImage: "stethoscope") }
            }
            Divider()
            HStack {
                if model.diagnostics.lastError != nil {
                    Label("Check Diagnostics for details", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Revert") { draft = model.configuration }
                Button("Save") { model.saveConfiguration(draft) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 540, minHeight: 390)
        .onReceive(model.$configuration) { updated in
            if updated != draft { draft = updated }
        }
    }

    private var general: some View {
        Form {
            Toggle("Launch at login", isOn: $draft.launchAtLogin)
            Picker("Yabai executable", selection: Binding(
                get: { draft.yabaiPath == "auto" ? "auto" : "custom" },
                set: { draft.yabaiPath = $0 == "auto" ? "auto" : "/opt/homebrew/bin/yabai" }
            )) {
                Text("Auto").tag("auto")
                Text("Custom path").tag("custom")
            }
            if draft.yabaiPath != "auto" {
                TextField("Absolute path", text: $draft.yabaiPath)
            }
            Picker("Space text", selection: $draft.spaceDisplay) {
                Text("Number").tag(SpaceDisplayMode.index)
                Text("Label").tag(SpaceDisplayMode.label)
                Text("Label fallback").tag(SpaceDisplayMode.labelOrIndex)
            }
            Toggle("Show empty spaces", isOn: $draft.showEmptySpaces)
            Toggle("Show spaces visible on other displays", isOn: $draft.showVisibleSpaces)
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var appearance: some View {
        Form {
            Picker("Active indicator", selection: $draft.activeStyle) {
                Text("Pill").tag(ActiveIndicatorStyle.pill)
                Text("Underline").tag(ActiveIndicatorStyle.underline)
                Text("Bold text").tag(ActiveIndicatorStyle.bold)
            }
            Toggle("Show occupied indicators", isOn: $draft.showOccupiedIndicators)
            Picker("Spacing", selection: $draft.spacing) {
                Text("Compact").tag(SpaceSpacing.compact)
                Text("Regular").tag(SpaceSpacing.regular)
                Text("Relaxed").tag(SpaceSpacing.relaxed)
            }
            Picker("Font", selection: $draft.font) {
                Text("System").tag(BarFont.system)
                Text("Monospaced").tag(BarFont.monospaced)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var diagnostics: some View {
        let snapshot = model.diagnostics
        return Form {
            LabeledContent("Yabai path", value: snapshot.yabaiPath ?? "Not found")
            LabeledContent("Yabai version", value: snapshot.version?.description ?? "Unknown")
            LabeledContent("Yabai status", value: snapshot.availability.displayName)
            LabeledContent("SIP", value: snapshot.sipStatus.displayName)
            LabeledContent("Spaces", value: String(snapshot.spaceCount))
            LabeledContent("Displays", value: String(snapshot.displayCount))
            LabeledContent("Signal bridge", value: snapshot.signalBridgeHealthy ? "Healthy" : "Unavailable")
            if let error = snapshot.lastError {
                Section("Last error") {
                    Text(error).textSelection(.enabled).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }
}

private extension YabaiAvailability {
    var displayName: String {
        switch self {
        case .supported: return "Running"
        case .unsupportedOldVersion: return "Update required"
        case .notInstalled: return "Not installed"
        case .notRunning: return "Not running"
        }
    }
}

private extension SIPStatus {
    var displayName: String {
        switch self {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .partiallyDisabled: return "Partially disabled"
        case .unknown: return "Unknown"
        }
    }
}
