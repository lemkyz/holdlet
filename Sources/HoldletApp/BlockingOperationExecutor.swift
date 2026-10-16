import Foundation

/// Security.framework may wait for a system dialog. Never run it on the UI actor.
final class BlockingOperationExecutor: @unchecked Sendable {
    enum Failure: Error { case busy, timedOut }
    private let queue = DispatchQueue(label: "io.github.lemkyz.holdlet.keychain", qos: .userInitiated)
    private let lock = NSLock()
    private var running = false

    func run<T: Sendable>(timeout: TimeInterval? = nil, _ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            guard !running else { lock.unlock(); continuation.resume(throwing: Failure.busy); return }
            running = true; lock.unlock()
            let completion = Completion(continuation)
            queue.async {
                let result = Result { try operation() }
                self.lock.lock(); self.running = false; self.lock.unlock()
                completion.resolve(result)
            }
            if let timeout {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    completion.resolve(.failure(Failure.timedOut))
                }
            }
        }
    }

    private final class Completion<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, Error>?
        init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }
        func resolve(_ result: Result<T, Error>) {
            lock.lock(); let pending = continuation; continuation = nil; lock.unlock()
            pending?.resume(with: result)
        }
    }
}
