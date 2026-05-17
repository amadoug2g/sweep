import Foundation

// MARK: - Storage

public protocol KeychainStoring: Sendable {
    @discardableResult
    func save(key: String, value: String) -> Bool
    func load(key: String) -> String?
    func delete(key: String)
}

public protocol ContextStoring: Sendable {
    func load() throws -> ContextProfile
    func save(_ profile: ContextProfile) throws
}

// MARK: - Scanning

public protocol DownloadsScanning: Sendable {
    func scan() async throws -> ScanReport
}

// MARK: - Intelligence

public protocol ClaudeClienting: Sendable {
    func propose(files: [FileItem], context: ContextProfile) async throws -> [PlannedItem]
}

// MARK: - Execution

public protocol ActionExecuting: Sendable {
    func execute(_ items: [PlannedItem], batchId: UUID) async throws -> [UndoRecord]
}

public protocol UndoLogging: Sendable {
    func record(_ record: UndoRecord) throws
    @discardableResult
    func undo(id: UUID) throws -> UndoRecord
    func undoLastBatch(batchId: UUID) throws -> [UndoRecord]
    func recentRecords(limit: Int) -> [UndoRecord]
    func purgeOlderThan(days: Int) throws
}

// MARK: - Notifications

public protocol Notifying: Sendable {
    func notifyBatchComplete(executed: [UndoRecord], pendingReviewCount: Int) async
}

// MARK: - Trust

public protocol TrustPhasing: Sendable {
    var autoActEnabled: Bool { get }
    var isInTrustPeriod: Bool { get }
    func recordSuccessfulAction()
    func recordUndoAction()
    func enableAutoAct()
    func disableAutoAct()
}
