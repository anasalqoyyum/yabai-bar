import Foundation
import XCTest
@testable import YabaiBarCore

final class YabaiBarCoreTests: XCTestCase {
    func testDecodesCurrentSpaceFields() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "spaces", withExtension: "json", subdirectory: "Fixtures"))
        let spaces = try JSONDecoder().decode([YabaiSpace].self, from: Data(contentsOf: url))

        XCTAssertEqual(spaces.count, 3)
        XCTAssertTrue(spaces[1].hasFocus)
        XCTAssertTrue(spaces[2].isNativeFullscreen)
        XCTAssertEqual(spaces[2].display, 2)
        XCTAssertEqual(spaces[0].windows, [101, 102])
        XCTAssertTrue(spaces[0].isOccupied)
    }

    func testDisplayModesAndEmptySpaceFiltering() {
        let spaces = fixtureSpaces()
        var configuration = AppConfiguration(spaceDisplay: .labelOrIndex, showEmptySpaces: false)

        XCTAssertEqual(configuration.title(for: spaces[0]), "web")
        XCTAssertEqual(configuration.title(for: spaces[2]), "3")
        XCTAssertEqual(configuration.displayedSpaces(from: spaces).map(\.index), [1, 2, 3])

        configuration.spaceDisplay = .label
        XCTAssertEqual(configuration.title(for: spaces[2]), "")
    }

    func testSemanticVersionParsingAndComparison() {
        XCTAssertEqual(SemanticVersion("yabai-v7.1.25"), SemanticVersion(major: 7, minor: 1, patch: 25))
        XCTAssertEqual(SemanticVersion("7.2.0\n"), SemanticVersion(major: 7, minor: 2, patch: 0))
        XCTAssertNil(SemanticVersion("unknown"))
        XCTAssertLessThan(SemanticVersion(major: 7, minor: 1, patch: 18), YabaiClient.minimumVersion)
    }

    func testSIPParsing() {
        XCTAssertEqual(SIPStatus(output: "System Integrity Protection status: enabled."), .enabled)
        XCTAssertEqual(SIPStatus(output: "System Integrity Protection status: disabled."), .disabled)
        XCTAssertEqual(SIPStatus(output: "enabled (Custom Configuration)."), .partiallyDisabled)
        XCTAssertEqual(SIPStatus(output: "no result"), .unknown)
    }

    func testDisablesKnownBrokenMacOS27SIPEnabledFocus() {
        let macOS27 = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        let currentYabai = SemanticVersion(major: 7, minor: 1, patch: 25)

        XCTAssertFalse(SpaceFocusSupport.isAvailable(
            operatingSystemVersion: macOS27,
            sipStatus: .enabled,
            yabaiVersion: currentYabai
        ))
    }

    func testKeepsFocusEnabledOutsideKnownBrokenCombination() {
        let macOS26 = OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 2)
        let macOS27 = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        let macOS28 = OperatingSystemVersion(majorVersion: 28, minorVersion: 0, patchVersion: 0)
        let currentYabai = SemanticVersion(major: 7, minor: 1, patch: 25)
        let futureYabai = SemanticVersion(major: 7, minor: 1, patch: 26)

        XCTAssertTrue(SpaceFocusSupport.isAvailable(
            operatingSystemVersion: macOS26,
            sipStatus: .enabled,
            yabaiVersion: currentYabai
        ))
        XCTAssertTrue(SpaceFocusSupport.isAvailable(
            operatingSystemVersion: macOS27,
            sipStatus: .partiallyDisabled,
            yabaiVersion: currentYabai
        ))
        XCTAssertTrue(SpaceFocusSupport.isAvailable(
            operatingSystemVersion: macOS27,
            sipStatus: .enabled,
            yabaiVersion: futureYabai
        ))
        XCTAssertTrue(SpaceFocusSupport.isAvailable(
            operatingSystemVersion: macOS28,
            sipStatus: .enabled,
            yabaiVersion: currentYabai
        ))
    }

    func testConfigurationDefaultsAndPartialDecoding() throws {
        XCTAssertEqual(try JSONDecoder().decode(AppConfiguration.self, from: Data("{}".utf8)), AppConfiguration())
        let partial = try JSONDecoder().decode(
            AppConfiguration.self,
            from: Data(#"{"spaceDisplay":"label","showEmptySpaces":false}"#.utf8)
        )
        XCTAssertEqual(partial.spaceDisplay, .label)
        XCTAssertFalse(partial.showEmptySpaces)
        XCTAssertTrue(partial.showVisibleSpaces)
        XCTAssertTrue(partial.showOccupiedIndicators)

        let hiddenOccupiedIndicators = try JSONDecoder().decode(
            AppConfiguration.self,
            from: Data(#"{"showOccupiedIndicators":false}"#.utf8)
        )
        XCTAssertFalse(hiddenOccupiedIndicators.showOccupiedIndicators)
    }

    func testConfigurationWritesAtomicallyAndReloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = ConfigurationFile(url: directory.appendingPathComponent("config.json"))
        var configuration = AppConfiguration()
        configuration.spacing = .relaxed
        try file.save(configuration)
        XCTAssertEqual(try file.load(), configuration)
        try? FileManager.default.removeItem(at: directory)
    }

    func testClientNormalizesAlreadyFocusedRace() async throws {
        let runner = FakeRunner(results: [
            ProcessResult(exitCode: 1, standardError: "cannot focus space due to an equal space")
        ])
        let client = YabaiClient(executableURL: URL(fileURLWithPath: "/fake/yabai"), runner: runner)

        try await client.focusSpace(index: 3)
        let invocations = await runner.invocations
        XCTAssertEqual(invocations.first?.arguments, ["-m", "space", "--focus", "3"])
    }

    func testAlreadyFocusedSpaceDoesNotExecuteCommand() async throws {
        let runner = FakeRunner(results: [])
        let client = YabaiClient(executableURL: URL(fileURLWithPath: "/fake/yabai"), runner: runner)

        try await client.focusSpace(index: 3, currentFocusedSpaceIndex: 3)

        let invocations = await runner.invocations
        XCTAssertTrue(invocations.isEmpty)
    }

    func testClientReportsGenuineFocusFailure() async {
        let runner = FakeRunner(results: [ProcessResult(exitCode: 1, standardError: "connection refused")])
        let client = YabaiClient(executableURL: URL(fileURLWithPath: "/fake/yabai"), runner: runner)

        do {
            try await client.focusSpace(index: 2)
            XCTFail("Expected focus failure")
        } catch let error as YabaiClientError {
            XCTAssertEqual(error, .commandFailed(arguments: ["-m", "space", "--focus", "2"], message: "connection refused"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnsupportedVersion() async {
        let runner = FakeRunner(results: [ProcessResult(exitCode: 0, standardOutput: "yabai-v7.1.18")])
        let client = YabaiClient(executableURL: URL(fileURLWithPath: "/fake/yabai"), runner: runner)
        do {
            _ = try await client.checkSupportedVersion()
            XCTFail("Expected old-version failure")
        } catch let error as YabaiClientError {
            XCTAssertEqual(error, .unsupportedVersion(SemanticVersion(major: 7, minor: 1, patch: 18)))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExplicitExecutableDiscovery() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("yabai")
        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let resolver = YabaiExecutableResolver(runner: FakeRunner(results: []))
        let result = await resolver.resolve(configuredPath: executable.path)
        XCTAssertEqual(result, executable)
        try? FileManager.default.removeItem(at: directory)
    }

    func testSignalReconciliationTouchesOnlyOwnedSignals() async throws {
        let existing = """
        [{"index":1,"label":"user.keep","event":"space_changed","action":"echo keep"},
         {"index":2,"label":"yabai-bar.old","event":"space_changed","action":"old"}]
        """
        var results = [ProcessResult(exitCode: 0, standardOutput: existing)]
        results.append(ProcessResult(exitCode: 0))
        results.append(contentsOf: SignalReconciler.definitions.map { _ in ProcessResult(exitCode: 0) })
        let runner = FakeRunner(results: results)
        let client = YabaiClient(executableURL: URL(fileURLWithPath: "/fake/yabai"), runner: runner)
        let reconciler = SignalReconciler(client: client, helperPath: "/Applications/Yabai Bar.app/Contents/MacOS/yabai-barctl")

        try await reconciler.reconcile()
        let arguments = await runner.invocations.map(\.arguments)
        XCTAssertEqual(arguments.first, ["-m", "signal", "--list"])
        XCTAssertTrue(arguments.contains(["-m", "signal", "--remove", "yabai-bar.old"]))
        XCTAssertFalse(arguments.contains(["-m", "signal", "--remove", "user.keep"]))
        XCTAssertEqual(arguments.filter { $0.prefix(3) == ["-m", "signal", "--add"] }.count, SignalReconciler.definitions.count)
    }

    func testDebouncerCoalescesBurst() async throws {
        let debouncer = Debouncer(delay: .milliseconds(30))
        let counter = Counter()
        await debouncer.schedule { await counter.increment() }
        await debouncer.schedule { await counter.increment() }
        await debouncer.schedule { await counter.increment() }
        try await Task.sleep(for: .milliseconds(80))
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }

    func testUnixSocketRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("test.sock")
        let server = UnixSocketServer(url: url) { command in
            IPCResponse(ok: command == .refresh, message: "received")
        }
        try server.start()
        defer {
            server.stop()
            try? FileManager.default.removeItem(at: directory)
        }
        let response = try UnixSocketClient().send(.refresh, to: url)
        XCTAssertEqual(response, IPCResponse(ok: true, message: "received"))
    }

    private func fixtureSpaces() -> [YabaiSpace] {
        [
            YabaiSpace(id: 1, index: 1, label: "web", display: 1, hasFocus: false, isVisible: false, isNativeFullscreen: false, windows: [10]),
            YabaiSpace(id: 2, index: 2, label: "code", display: 1, hasFocus: true, isVisible: true, isNativeFullscreen: false),
            YabaiSpace(id: 3, index: 3, label: "", display: 2, hasFocus: false, isVisible: true, isNativeFullscreen: true),
        ]
    }
}

private actor FakeRunner: ProcessRunning {
    struct Invocation: Sendable { let executableURL: URL; let arguments: [String] }
    private var results: [ProcessResult]
    private(set) var invocations: [Invocation] = []

    init(results: [ProcessResult]) { self.results = results }

    func run(executableURL: URL, arguments: [String]) async throws -> ProcessResult {
        invocations.append(Invocation(executableURL: executableURL, arguments: arguments))
        guard !results.isEmpty else { return ProcessResult(exitCode: 1) }
        return results.removeFirst()
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
