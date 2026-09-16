import Foundation

final class ConfigurationWatcher {
    private let fileURL: URL
    private let handler: @Sendable () -> Void
    private let queue = DispatchQueue(label: "dev.yabaibar.configuration")
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1

    init(fileURL: URL, handler: @escaping @Sendable () -> Void) {
        self.fileURL = fileURL
        self.handler = handler
    }

    deinit { stop() }

    func start() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileReadUnknown) }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        source.setEventHandler(handler: handler)
        source.setCancelHandler { [descriptor] in close(descriptor) }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
        descriptor = -1
    }
}
