import Foundation

public actor Debouncer {
    private let delay: Duration
    private var pendingTask: Task<Void, Never>?

    public init(delay: Duration = .milliseconds(35)) {
        self.delay = delay
    }

    public func schedule(_ operation: @escaping @Sendable () async -> Void) {
        pendingTask?.cancel()
        pendingTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    public func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
