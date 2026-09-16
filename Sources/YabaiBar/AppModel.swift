import AppKit
import Combine
import ServiceManagement
import YabaiBarCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var spaces: [YabaiSpace] = []
    @Published private(set) var diagnostics = DiagnosticsSnapshot()
    @Published var configuration: AppConfiguration

    private let configurationFile: ConfigurationFile
    private let resolver: YabaiExecutableResolver
    private let client: YabaiClient
    private let sipDetector: SIPDetector
    private let debouncer = Debouncer()
    private var reconciler: SignalReconciler?
    private var socketServer: UnixSocketServer?
    private var healthTask: Task<Void, Never>?
    private var configurationWatcher: ConfigurationWatcher?
    private var helperPath = ""
    private var pendingRecovery = false

    init(
        configurationFile: ConfigurationFile = ConfigurationFile(),
        resolver: YabaiExecutableResolver = YabaiExecutableResolver(),
        client: YabaiClient = YabaiClient(),
        sipDetector: SIPDetector = SIPDetector()
    ) {
        self.configurationFile = configurationFile
        self.resolver = resolver
        self.client = client
        self.sipDetector = sipDetector
        configuration = (try? configurationFile.load()) ?? AppConfiguration()
    }

    var displayedSpaces: [YabaiSpace] { configuration.displayedSpaces(from: spaces) }

    func start() async {
        helperPath = Bundle.main.url(forAuxiliaryExecutable: "yabai-barctl")?.path
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/yabai-barctl").path
        startSocketServer()
        startConfigurationWatcher()
        updateLaunchAtLogin(configuration.launchAtLogin)
        await connect(reconcileSignals: true)
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await self?.healthCheck()
            }
        }
    }

    func stop() async {
        healthTask?.cancel()
        await debouncer.cancel()
        configurationWatcher?.stop()
        socketServer?.stop()
        await reconciler?.removeOwnedSignals()
    }

    func focusSpace(_ index: Int) {
        guard diagnostics.spaceFocusAvailable else { return }
        let focusedIndex = spaces.first(where: \.hasFocus)?.index
        Task {
            do {
                try await client.focusSpace(index: index, currentFocusedSpaceIndex: focusedIndex)
            } catch {
                if (try? await client.version()) == nil {
                    markDisconnected(error)
                } else {
                    diagnostics.lastError = "Could not focus space \(index): \(error.localizedDescription)"
                }
            }
        }
    }

    func refresh() {
        Task { await refreshSpaces() }
    }

    func receive(event: String) async {
        if event == "dock_did_restart" || event == "system_woke" {
            pendingRecovery = true
        }
        await debouncer.schedule { [weak self] in
            await self?.handleDebouncedEvents()
        }
    }

    func saveConfiguration(_ updated: AppConfiguration) {
        let previousPath = configuration.yabaiPath
        do {
            try configurationFile.save(updated)
            configuration = updated
            updateLaunchAtLogin(updated.launchAtLogin)
            if previousPath != updated.yabaiPath {
                Task { await connect(reconcileSignals: true) }
            }
        } catch {
            diagnostics.lastError = "Could not save settings: \(error.localizedDescription)"
        }
    }

    private func connect(reconcileSignals: Bool) async {
        guard let executable = await resolver.resolve(configuredPath: configuration.yabaiPath) else {
            await client.setExecutableURL(nil)
            diagnostics = DiagnosticsSnapshot(
                availability: .notInstalled,
                sipStatus: await sipDetector.status(),
                lastError: "Set the yabai path in Settings or install yabai in a standard location."
            )
            spaces = []
            return
        }

        await client.setExecutableURL(executable)
        do {
            let version = try await client.checkSupportedVersion()
            let sipStatus = await sipDetector.status()
            let reconciler = SignalReconciler(client: client, helperPath: helperPath)
            if reconcileSignals { try await reconciler.reconcile() }
            let spaces = try await client.spaces()
            self.reconciler = reconciler
            self.spaces = spaces
            diagnostics = DiagnosticsSnapshot(
                availability: .supported,
                yabaiPath: executable.path,
                version: version,
                sipStatus: sipStatus,
                spaceCount: spaces.count,
                displayCount: Set(spaces.map(\.display)).count,
                signalBridgeHealthy: await reconciler.isHealthy(),
                spaceFocusAvailable: SpaceFocusSupport.isAvailable(
                    operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion,
                    sipStatus: sipStatus,
                    yabaiVersion: version
                )
            )
        } catch YabaiClientError.unsupportedVersion(let version) {
            spaces = []
            diagnostics = DiagnosticsSnapshot(
                availability: .unsupportedOldVersion,
                yabaiPath: executable.path,
                version: version,
                sipStatus: await sipDetector.status(),
                lastError: YabaiClientError.unsupportedVersion(version).localizedDescription
            )
        } catch {
            spaces = []
            diagnostics = DiagnosticsSnapshot(
                availability: .notRunning,
                yabaiPath: executable.path,
                sipStatus: await sipDetector.status(),
                lastError: error.localizedDescription
            )
        }
    }

    private func refreshSpaces() async {
        do {
            let updatedSpaces = try await client.spaces()
            spaces = updatedSpaces
            diagnostics.availability = .supported
            diagnostics.spaceCount = updatedSpaces.count
            diagnostics.displayCount = Set(updatedSpaces.map(\.display)).count
            diagnostics.lastError = nil
        } catch {
            markDisconnected(error)
        }
    }

    private func handleDebouncedEvents() async {
        let shouldRecover = pendingRecovery
        pendingRecovery = false
        if shouldRecover {
            await connect(reconcileSignals: true)
        } else {
            await refreshSpaces()
        }
    }

    private func healthCheck() async {
        guard diagnostics.availability == .supported, let reconciler else {
            await connect(reconcileSignals: true)
            return
        }
        do {
            let version = try await client.checkSupportedVersion()
            diagnostics.version = version
            diagnostics.spaceFocusAvailable = SpaceFocusSupport.isAvailable(
                operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion,
                sipStatus: diagnostics.sipStatus,
                yabaiVersion: version
            )
            let healthy = await reconciler.isHealthy()
            diagnostics.signalBridgeHealthy = healthy
            if !healthy {
                try await reconciler.reconcile()
                diagnostics.signalBridgeHealthy = await reconciler.isHealthy()
                await refreshSpaces()
            }
        } catch {
            markDisconnected(error)
        }
    }

    private func markDisconnected(_ error: Error) {
        diagnostics.availability = .notRunning
        diagnostics.signalBridgeHealthy = false
        diagnostics.lastError = error.localizedDescription
    }

    private func startSocketServer() {
        let server = UnixSocketServer(url: IPCPaths.socketURL()) { [weak self] command in
            guard let self else { return IPCResponse(ok: false, message: "Yabai Bar is stopping.") }
            switch command {
            case .event(let event):
                await self.receive(event: event)
                return IPCResponse(ok: true)
            case .refresh:
                await self.refreshSpaces()
                return IPCResponse(ok: true)
            case .status:
                return await IPCResponse(ok: true, diagnostics: self.diagnosticsSnapshot)
            }
        }
        do {
            try server.start()
            socketServer = server
        } catch {
            diagnostics.signalBridgeHealthy = false
            diagnostics.lastError = "Could not start the signal bridge: \(error.localizedDescription)"
        }
    }

    private var diagnosticsSnapshot: DiagnosticsSnapshot { diagnostics }

    private func startConfigurationWatcher() {
        let watcher = ConfigurationWatcher(fileURL: configurationFile.url) { [weak self] in
            Task { @MainActor [weak self] in self?.reloadConfiguration() }
        }
        try? watcher.start()
        configurationWatcher = watcher
    }

    private func reloadConfiguration() {
        guard let updated = try? configurationFile.load(), updated != configuration else { return }
        let pathChanged = configuration.yabaiPath != updated.yabaiPath
        configuration = updated
        updateLaunchAtLogin(updated.launchAtLogin)
        if pathChanged { Task { await connect(reconcileSignals: true) } }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled, SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register()
            } else if !enabled, SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            diagnostics.lastError = "Could not update launch at login: \(error.localizedDescription)"
        }
    }
}
