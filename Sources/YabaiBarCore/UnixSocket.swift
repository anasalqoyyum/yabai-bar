import Darwin
import Foundation

public enum UnixSocketError: LocalizedError {
    case pathTooLong
    case systemCall(String, Int32)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .pathTooLong: return "The Unix socket path is too long."
        case .systemCall(let operation, let code): return "\(operation) failed: \(String(cString: strerror(code)))"
        case .invalidResponse: return "The app returned an invalid response."
        }
    }
}

private func socketAddress(path: String) throws -> (sockaddr_un, socklen_t) {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8) + [0]
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard bytes.count <= capacity else { throw UnixSocketError.pathTooLong }
    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
        buffer.copyBytes(from: bytes)
    }
    let length = MemoryLayout.offset(of: \sockaddr_un.sun_path)! + bytes.count
    return (address, socklen_t(length))
}

public struct UnixSocketClient: Sendable {
    public init() {}

    public func send(_ command: IPCCommand, to url: URL, timeout: TimeInterval = 2) throws -> IPCResponse {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw UnixSocketError.systemCall("socket", errno) }
        defer { Darwin.close(descriptor) }

        var timeValue = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeValue, socklen_t(MemoryLayout<timeval>.size))
        var (address, length) = try socketAddress(path: url.path)
        let connectionResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, length)
            }
        }
        guard connectionResult == 0 else { throw UnixSocketError.systemCall("connect", errno) }

        var request = try JSONEncoder().encode(command)
        request.append(0x0A)
        try writeAll(request, to: descriptor)
        let responseData = try readLine(from: descriptor)
        guard let response = try? JSONDecoder().decode(IPCResponse.self, from: responseData) else {
            throw UnixSocketError.invalidResponse
        }
        return response
    }
}

public final class UnixSocketServer: @unchecked Sendable {
    public typealias Handler = @Sendable (IPCCommand) async -> IPCResponse

    private let url: URL
    private let handler: Handler
    private let queue = DispatchQueue(label: "dev.yabaibar.socket")
    private let lock = NSLock()
    private var descriptor: Int32 = -1
    private var running = false

    public init(url: URL, handler: @escaping Handler) {
        self.url = url
        self.handler = handler
    }

    deinit { stop() }

    public func start() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: url)
        let newDescriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard newDescriptor >= 0 else { throw UnixSocketError.systemCall("socket", errno) }

        var (address, length) = try socketAddress(path: url.path)
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(newDescriptor, $0, length)
            }
        }
        guard bindResult == 0 else {
            let code = errno
            Darwin.close(newDescriptor)
            throw UnixSocketError.systemCall("bind", code)
        }
        guard Darwin.listen(newDescriptor, 8) == 0 else {
            let code = errno
            Darwin.close(newDescriptor)
            throw UnixSocketError.systemCall("listen", code)
        }

        lock.lock()
        descriptor = newDescriptor
        running = true
        lock.unlock()
        queue.async { [weak self] in self?.acceptConnections() }
    }

    public func stop() {
        lock.lock()
        guard running else {
            lock.unlock()
            return
        }
        running = false
        let activeDescriptor = descriptor
        descriptor = -1
        lock.unlock()
        Darwin.shutdown(activeDescriptor, SHUT_RDWR)
        Darwin.close(activeDescriptor)
        try? FileManager.default.removeItem(at: url)
    }

    private func acceptConnections() {
        while isRunning {
            let client = Darwin.accept(currentDescriptor, nil, nil)
            guard client >= 0 else {
                if isRunning { continue }
                return
            }
            Task { [handler] in
                defer { Darwin.close(client) }
                do {
                    let data = try readLine(from: client)
                    let command = try JSONDecoder().decode(IPCCommand.self, from: data)
                    var response = try JSONEncoder().encode(await handler(command))
                    response.append(0x0A)
                    try writeAll(response, to: client)
                } catch {
                    let response = IPCResponse(ok: false, message: error.localizedDescription)
                    if var data = try? JSONEncoder().encode(response) {
                        data.append(0x0A)
                        try? writeAll(data, to: client)
                    }
                }
            }
        }
    }

    private var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    private var currentDescriptor: Int32 {
        lock.lock()
        defer { lock.unlock() }
        return descriptor
    }
}

private func readLine(from descriptor: Int32) throws -> Data {
    var data = Data()
    var byte: UInt8 = 0
    while data.count < 1_048_576 {
        let count = Darwin.read(descriptor, &byte, 1)
        if count == 0 { break }
        guard count > 0 else { throw UnixSocketError.systemCall("read", errno) }
        if byte == 0x0A { break }
        data.append(byte)
    }
    return data
}

private func writeAll(_ data: Data, to descriptor: Int32) throws {
    try data.withUnsafeBytes { buffer in
        guard var pointer = buffer.baseAddress else { return }
        var remaining = buffer.count
        while remaining > 0 {
            let count = Darwin.write(descriptor, pointer, remaining)
            guard count > 0 else { throw UnixSocketError.systemCall("write", errno) }
            remaining -= count
            pointer = pointer.advanced(by: count)
        }
    }
}
