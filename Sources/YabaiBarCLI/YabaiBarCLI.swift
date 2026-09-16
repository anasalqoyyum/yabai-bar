import Foundation
import YabaiBarCore

enum ExitCode: Int32 {
    case success = 0
    case usage = 64
    case unavailable = 69
}

@main
enum YabaiBarCommand {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = parse(arguments) else {
            writeError("Usage: yabai-barctl event <event> | refresh | status [--json] | doctor")
            exit(ExitCode.usage.rawValue)
        }

        do {
            let response = try UnixSocketClient().send(command.command, to: IPCPaths.socketURL())
            guard response.ok else {
                writeError(response.message ?? "Yabai Bar rejected the request.")
                exit(ExitCode.unavailable.rawValue)
            }
            printResponse(response, mode: command.mode)
        } catch {
            writeError("Yabai Bar is not reachable: \(error.localizedDescription)")
            exit(ExitCode.unavailable.rawValue)
        }
    }

    private enum OutputMode { case quiet, textStatus, json, doctor }
    private struct ParsedCommand { let command: IPCCommand; let mode: OutputMode }

    private static func parse(_ arguments: [String]) -> ParsedCommand? {
        switch arguments.first {
        case "event" where arguments.count == 2:
            return ParsedCommand(command: .event(arguments[1]), mode: .quiet)
        case "refresh" where arguments.count == 1:
            return ParsedCommand(command: .refresh, mode: .quiet)
        case "status" where arguments.count == 1:
            return ParsedCommand(command: .status, mode: .textStatus)
        case "status" where arguments == ["status", "--json"]:
            return ParsedCommand(command: .status, mode: .json)
        case "doctor" where arguments.count == 1:
            return ParsedCommand(command: .status, mode: .doctor)
        default:
            return nil
        }
    }

    private static func printResponse(_ response: IPCResponse, mode: OutputMode) {
        guard let diagnostics = response.diagnostics else { return }
        switch mode {
        case .quiet:
            return
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            if let data = try? encoder.encode(diagnostics) { print(String(decoding: data, as: UTF8.self)) }
        case .textStatus:
            print("status: \(diagnostics.availability.rawValue)")
            print("yabai: \(diagnostics.yabaiPath ?? "not found")")
            print("spaces: \(diagnostics.spaceCount)")
            print("space focus: \(diagnostics.spaceFocusAvailable ? "available" : "unavailable")")
            print("signal bridge: \(diagnostics.signalBridgeHealthy ? "healthy" : "unavailable")")
        case .doctor:
            print("Yabai Bar")
            print("✓ app running")
            check(diagnostics.yabaiPath != nil, "yabai found: \(diagnostics.yabaiPath ?? "not found")")
            check(diagnostics.version != nil, "yabai version: \(diagnostics.version?.description ?? "unknown")")
            check(diagnostics.availability == .supported, "supported version")
            check(diagnostics.availability == .supported, "yabai responding")
            print("✓ SIP: \(diagnostics.sipStatus.rawValue)")
            check(diagnostics.spaceFocusAvailable, "space focus available")
            check(diagnostics.spaceCount > 0, "\(diagnostics.spaceCount) spaces")
            check(diagnostics.signalBridgeHealthy, "signal bridge healthy")
        }
    }

    private static func check(_ condition: Bool, _ message: String) {
        print("\(condition ? "✓" : "✗") \(message)")
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
