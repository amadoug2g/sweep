import Foundation
@testable import Sweep

// MARK: - MockDownloadsScanner

public final class MockDownloadsScanner: DownloadsScanning, @unchecked Sendable {

    /// Set to make `scan()` return a specific report.
    public var stubbedReport: ScanReport?

    /// Set to make `scan()` throw this error.
    public var stubbedError: Error?

    public private(set) var scanCallCount = 0

    public init(items: [FileItem] = [], skippedCount: Int = 0) {
        self.stubbedReport = ScanReport(items: items, skippedCount: skippedCount)
    }

    public func scan() async throws -> ScanReport {
        scanCallCount += 1
        if let error = stubbedError { throw error }
        return stubbedReport ?? ScanReport(items: [], skippedCount: 0)
    }
}

// MARK: - MockActionExecutor

public final class MockActionExecutor: ActionExecuting, @unchecked Sendable {

    /// Records every `(items, batchId)` call received.
    public private(set) var executeCalls: [([PlannedItem], UUID)] = []

    /// Returned by every `execute` call.
    public var stubbedRecords: [UndoRecord] = []

    /// Set to make `execute` throw this error.
    public var stubbedError: Error?

    public init() {}

    public func execute(_ items: [PlannedItem], batchId: UUID) async throws -> [UndoRecord] {
        executeCalls.append((items, batchId))
        if let error = stubbedError { throw error }
        return stubbedRecords
    }
}

// MARK: - MockUndoLog

public final class MockUndoLog: UndoLogging, @unchecked Sendable {

    private var store: [UndoRecord] = []

    /// If set, `record(_:)` throws this error instead of storing the record.
    public var recordError: Error?

    public private(set) var recordCalls: [UndoRecord] = []
    public private(set) var undoCalls: [UUID] = []

    public init() {}

    // MARK: UndoLogging

    public func record(_ record: UndoRecord) throws {
        recordCalls.append(record)
        if let error = recordError { throw error }
        store.append(record)
    }

    @discardableResult
    public func undo(id: UUID) throws -> UndoRecord {
        undoCalls.append(id)
        guard let idx = store.firstIndex(where: { $0.id == id }) else {
            throw UndoError.recordNotFound(id)
        }
        store[idx].undoneAt = Date()
        return store[idx]
    }

    public func undoLastBatch(batchId: UUID) throws -> [UndoRecord] {
        let targets = store
            .filter { $0.batchId == batchId && !$0.isUndone }
            .sorted { $0.timestamp > $1.timestamp }
        let now = Date()
        var undone: [UndoRecord] = []
        for target in targets {
            if let idx = store.firstIndex(where: { $0.id == target.id }) {
                store[idx].undoneAt = now
                undone.append(store[idx])
            }
        }
        return undone
    }

    public func recentRecords(limit: Int) -> [UndoRecord] {
        Array(store.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    public func purgeOlderThan(days: Int) throws {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        let hardCutoff = Date().addingTimeInterval(-90 * 86_400)
        store = store.filter { record in
            let isOldAndUndone = record.timestamp < cutoff && record.undoneAt != nil
            let isVeryOld = record.timestamp < hardCutoff
            return !isOldAndUndone && !isVeryOld
        }
    }

    // MARK: - Test Helpers

    /// Direct access to the in-memory store for test assertions.
    public var allRecords: [UndoRecord] { store }
}

// MARK: - MockNotificationService

public final class MockNotificationService: Notifying, @unchecked Sendable {

    public struct Call {
        public let executed: [UndoRecord]
        public let pendingReviewCount: Int
    }

    public private(set) var calls: [Call] = []

    public init() {}

    public func notifyBatchComplete(executed: [UndoRecord], pendingReviewCount: Int) async {
        calls.append(Call(executed: executed, pendingReviewCount: pendingReviewCount))
    }
}
