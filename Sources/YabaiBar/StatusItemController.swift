import AppKit
import Combine
import YabaiBarCore

@MainActor
final class StatusItemController: NSObject, WorkspaceStatusViewDelegate {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let workspaceView = WorkspaceStatusView()
    private let settingsController: SettingsWindowController
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        settingsController = SettingsWindowController(model: model)
        super.init()
        workspaceView.delegate = self
        if let button = statusItem.button {
            button.title = ""
            button.image = nil
            button.addSubview(workspaceView)
        }

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                DispatchQueue.main.async { self?.render() }
            }
            .store(in: &cancellables)
        render()
    }

    func workspaceStatusView(_ view: WorkspaceStatusView, didSelectSpace index: Int) {
        model.focusSpace(index)
    }

    func workspaceStatusViewDidRequestMenu(_ view: WorkspaceStatusView, event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Diagnostics…", action: #selector(openDiagnostics), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "About Yabai Bar", action: #selector(openAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    private func render() {
        workspaceView.update(
            spaces: model.displayedSpaces,
            configuration: model.configuration,
            available: model.diagnostics.availability == .supported,
            workspaceInteractionEnabled: model.diagnostics.spaceFocusAvailable
        )
        let size = workspaceView.intrinsicContentSize
        statusItem.length = size.width
        workspaceView.frame = NSRect(origin: .zero, size: size)
        statusItem.button?.frame.size.width = size.width
    }

    @objc private func refresh() { model.refresh() }

    @objc private func openSettings() {
        settingsController.show(tab: .general)
    }

    @objc private func openDiagnostics() {
        settingsController.show(tab: .diagnostics)
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
