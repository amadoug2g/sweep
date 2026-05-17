import SwiftUI
import os.log

@MainActor
public final class AppContainer: ObservableObject {

    // MARK: - Services

    let keychain: KeychainStoring
    let contextStore: ContextStoring
    let scanner: DownloadsScanning
    let claudeClient: ClaudeClienting
    let executor: ActionExecuting
    let undoLog: UndoLogging
    let notifier: Notifying
    let trust: TrustPhasing

    // MARK: - Published state

    @Published public var isScanning = false
    @Published public var lastScanDate: Date? = nil
    @Published public var pendingReviewItems: [PlannedItem] = []
    @Published public var recentActions: [UndoRecord] = []
    @Published public var downloadsCount: Int = 0
    @Published public var errorMessage: String? = nil

    // MARK: - Live singleton

    /// Shared production instance. The nonisolated(unsafe) annotation is intentional:
    /// the closure runs before the main run loop starts (from SweepMain.main()), and
    /// all captured service types are Sendable, so there is no data race.
    public nonisolated(unsafe) static let live: AppContainer = {
        let keychain = KeychainStore()
        let undoLog = UndoLog()
        return AppContainer(
            keychain: keychain,
            contextStore: ContextStore(),
            scanner: DownloadsScanner(),
            claudeClient: ClaudeClient(keychainStore: keychain),
            executor: ActionExecutor(undoLog: undoLog),
            undoLog: undoLog,
            notifier: NotificationService(),
            trust: TrustPhaseService()
        )
    }()

    // MARK: - Init (testable)

    public init(
        keychain: KeychainStoring,
        contextStore: ContextStoring,
        scanner: DownloadsScanning,
        claudeClient: ClaudeClienting,
        executor: ActionExecuting,
        undoLog: UndoLogging,
        notifier: Notifying,
        trust: TrustPhasing
    ) {
        self.keychain = keychain
        self.contextStore = contextStore
        self.scanner = scanner
        self.claudeClient = claudeClient
        self.executor = executor
        self.undoLog = undoLog
        self.notifier = notifier
        self.trust = trust
    }

    // MARK: - Sweep

    public func sweep() async {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }

        do {
            // 1. Load context
            let profile = try contextStore.load()

            // 2. Scan Downloads
            let report = try await scanner.scan()
            downloadsCount = report.items.count

            // 3. Ask Claude
            let planned = try await claudeClient.propose(files: report.items, context: profile)

            // 4. Split by confidence + trust phase
            let batchId = UUID()
            let autoActEnabled = trust.autoActEnabled && !trust.isInTrustPeriod
            let toExecute = planned.filter { item in
                autoActEnabled ? item.confidence == .high : false
            }
            let toReview = planned.filter { $0.confidence == .medium }

            // 5. Execute high-confidence (or stage everything to review during trust period)
            let allToReview: [PlannedItem]
            if autoActEnabled {
                // ActionExecutor records each UndoRecord to the log internally before
                // moving the file. We only need to notify and refresh here.
                let executed = try await executor.execute(toExecute, batchId: batchId)
                await notifier.notifyBatchComplete(executed: executed, pendingReviewCount: toReview.count)
                trust.recordSuccessfulAction()
                allToReview = toReview
            } else {
                // Trust period: stage everything to review, execute nothing
                allToReview = planned.filter { $0.confidence != .low }
            }

            // 6. Update state
            pendingReviewItems = allToReview
            lastScanDate = Date()
            refreshRecentActions()

        } catch {
            SweepLogger.ui.error("Sweep failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Undo

    /// Undo a single record.
    public func undo(record: UndoRecord) {
        do {
            try undoLog.undo(id: record.id)
            trust.recordUndoAction()
            refreshRecentActions()
        } catch {
            SweepLogger.ui.error("Undo failed for id=\(record.id): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Undo the last batch (uses the batchId from the most recent recentActions record).
    public func undoLastBatch() {
        guard let lastRecord = recentActions.first(where: { !$0.isUndone }) else { return }
        do {
            try undoLog.undoLastBatch(batchId: lastRecord.batchId)
            trust.recordUndoAction()
            refreshRecentActions()
        } catch {
            SweepLogger.ui.error("Undo last batch failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Reload recent actions from the undo log.
    public func refreshRecentActions() {
        recentActions = undoLog.recentRecords(limit: 5)
    }

    // MARK: - API key helpers

    public var hasAPIKey: Bool {
        keychain.load(key: "anthropic_api_key") != nil
    }

    public func saveAPIKey(_ key: String) {
        keychain.save(key: "anthropic_api_key", value: key)
    }
}
