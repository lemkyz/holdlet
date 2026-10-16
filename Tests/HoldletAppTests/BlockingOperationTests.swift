import Foundation
import Testing
@testable import HoldletApp

@MainActor
struct BlockingOperationTests {
    @Test func blockingWorkRunsAwayFromMainThread() async throws {
        let worker = BlockingOperationExecutor()
        let onMain = try await worker.run { Thread.isMainThread }
        #expect(!onMain)
    }

    @Test func timedOutReadDoesNotQueueMoreWorkAndLateCompletionIsSafe() async throws {
        let worker = BlockingOperationExecutor()
        let gate = DispatchSemaphore(value: 0)
        defer { gate.signal() }
        do {
            _ = try await worker.run(timeout: 0.05) { gate.wait(); return "late" }
            Issue.record("Expected the blocked read to time out")
        } catch BlockingOperationExecutor.Failure.timedOut { }
        do {
            _ = try await worker.run { "must not queue" }
            Issue.record("Expected busy until the original operation finishes")
        } catch BlockingOperationExecutor.Failure.busy { }
        gate.signal()
        var recovered = false
        for _ in 0..<30 {
            do { recovered = try await worker.run { true }; break }
            catch BlockingOperationExecutor.Failure.busy { try await Task.sleep(for: .milliseconds(10)) }
        }
        #expect(recovered)
    }
}
