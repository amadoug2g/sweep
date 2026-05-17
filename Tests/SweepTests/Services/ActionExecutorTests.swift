import XCTest
@testable import Sweep

final class ActionExecutorTests: XCTestCase {

    private var tempDir: URL!
    private var mockUndoLog: MockUndoLog!
    private var executor: ActionExecutor!
    private let batchId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepExecutorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockUndoLog = MockUndoLog()
        executor = ActionExecutor(undoLog: mockUndoLog)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a real file in tempDir and returns a FileItem pointing at it.
    private func makeSourceFile(named name: String = "test.pdf") throws -> (URL, FileItem) {
        let url = tempDir.appendingPathComponent(name)
        try "dummy content".write(to: url, atomically: true, encoding: .utf8)
        let item = FileItem(
            url: url,
            size: 13,
            createdAt: Date(),
            modifiedAt: Date()
        )
        return (url, item)
    }

    private func makePlanned(file: FileItem, action: ProposedAction) -> PlannedItem {
        PlannedItem(file: file, action: action, confidence: .high, reason: "test")
    }

    // MARK: - .keep

    func testKeepActionResultsInNoFileMove() async throws {
        let (srcURL, file) = try makeSourceFile()
        let planned = makePlanned(file: file, action: .keep(reason: "user preference"))

        let records = try await executor.execute([planned], batchId: batchId)

        XCTAssertTrue(records.isEmpty, "No records should be returned for .keep")
        XCTAssertTrue(FileManager.default.fileExists(atPath: srcURL.path), "File should remain in source")
        XCTAssertTrue(mockUndoLog.recordCalls.isEmpty, "Undo log should not be called for .keep")
    }

    // MARK: - .move

    func testMoveActionMovesFileToCorrectDestination() async throws {
        let destDir = tempDir.appendingPathComponent("Destination", isDirectory: true)
        let destURL = destDir.appendingPathComponent("test.pdf")

        let (srcURL, file) = try makeSourceFile()
        let action = ProposedAction.move(destination: destURL, reason: "organized")
        let planned = makePlanned(file: file, action: action)

        let records = try await executor.execute([planned], batchId: batchId)

        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: srcURL.path), "File should no longer be at source")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path), "File should exist at destination")
        XCTAssertEqual(records.first?.sourceURL, srcURL)
        XCTAssertEqual(records.first?.destinationURL, destURL)
    }

    // MARK: - .archive

    func testArchiveActionMovesFileToDateBasedArchiveSubfolder() async throws {
        let (srcURL, file) = try makeSourceFile()
        let planned = makePlanned(file: file, action: .archive(reason: "old file"))

        let records = try await executor.execute([planned], batchId: batchId)

        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: srcURL.path), "Source should be gone")

        // Verify destination path contains Archive and a yyyy-MM component.
        let destPath = records.first?.destinationURL.path ?? ""
        XCTAssertTrue(destPath.contains("Archive"), "Should be in Archive folder")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthFolder = formatter.string(from: Date())
        XCTAssertTrue(destPath.contains(monthFolder), "Should be in month subfolder \(monthFolder)")

        // Clean up archive location.
        if let destURL = records.first?.destinationURL {
            try? FileManager.default.removeItem(at: destURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
        }
    }

    // MARK: - .reviewLater

    func testReviewLaterActionMovesFileToReviewFolder() async throws {
        let (srcURL, file) = try makeSourceFile()
        let planned = makePlanned(file: file, action: .reviewLater(reason: "unclear"))

        let records = try await executor.execute([planned], batchId: batchId)

        XCTAssertEqual(records.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: srcURL.path), "Source should be gone")

        let destPath = records.first?.destinationURL.path ?? ""
        XCTAssertTrue(destPath.contains("Review"), "Should be in Review folder")

        // Clean up Review location.
        if let destURL = records.first?.destinationURL {
            try? FileManager.default.removeItem(at: destURL)
        }
    }

    // MARK: - Filename collision

    func testFilenameCollisionAppendsNumberSuffix() async throws {
        let destDir = tempDir.appendingPathComponent("CollisionDest", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Pre-create the destination file to force a collision.
        let existingDest = destDir.appendingPathComponent("test.pdf")
        try "existing".write(to: existingDest, atomically: true, encoding: .utf8)

        let (_, file) = try makeSourceFile()
        let action = ProposedAction.move(destination: existingDest, reason: "test collision")
        let planned = makePlanned(file: file, action: action)

        let records = try await executor.execute([planned], batchId: batchId)

        XCTAssertEqual(records.count, 1)
        let destName = records.first?.destinationURL.lastPathComponent ?? ""
        XCTAssertEqual(destName, "test (2).pdf", "Collision should produce 'test (2).pdf', got: \(destName)")

        // Original should still exist.
        XCTAssertTrue(FileManager.default.fileExists(atPath: existingDest.path))
    }

    // MARK: - UndoRecord written before move

    func testUndoRecordWrittenBeforeMove_moveAbortedWhenRecordFails() async throws {
        // Configure the mock to throw on record() — move should NOT happen.
        mockUndoLog.recordError = TestError.recordFailed

        let destDir = tempDir.appendingPathComponent("ShouldNotExist", isDirectory: true)
        let destURL = destDir.appendingPathComponent("test.pdf")

        let (srcURL, file) = try makeSourceFile()
        let action = ProposedAction.move(destination: destURL, reason: "test")
        let planned = makePlanned(file: file, action: action)

        let records = try await executor.execute([planned], batchId: batchId)

        // No successful records because the undo log write failed.
        XCTAssertTrue(records.isEmpty, "No records when undo log throws")
        // Source file must still be there (move was never attempted).
        XCTAssertTrue(FileManager.default.fileExists(atPath: srcURL.path), "File must remain at source")
    }

    // MARK: - One failed move doesn't abort remaining items

    func testOneFailedMoveDoesNotAbortRemainingItems() async throws {
        let destDir = tempDir.appendingPathComponent("MultiDest", isDirectory: true)

        // First file: source does not exist → move will fail.
        let nonExistentURL = tempDir.appendingPathComponent("ghost.pdf")
        let ghostFile = FileItem(url: nonExistentURL, size: 0, createdAt: Date(), modifiedAt: Date())
        let ghostAction = ProposedAction.move(
            destination: destDir.appendingPathComponent("ghost.pdf"),
            reason: "test"
        )
        let ghostPlanned = PlannedItem(file: ghostFile, action: ghostAction, confidence: .high, reason: "test")

        // Second file: valid, should succeed.
        let (_, goodFile) = try makeSourceFile(named: "good.pdf")
        let goodAction = ProposedAction.move(
            destination: destDir.appendingPathComponent("good.pdf"),
            reason: "test"
        )
        let goodPlanned = makePlanned(file: goodFile, action: goodAction)

        let records = try await executor.execute([ghostPlanned, goodPlanned], batchId: batchId)

        // Only the good file should produce a record.
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.destinationURL.lastPathComponent, "good.pdf")
    }

    // MARK: - UndoRecord fields

    func testUndoRecordFieldsAreCorrect() async throws {
        let destDir = tempDir.appendingPathComponent("Dest", isDirectory: true)
        let destURL = destDir.appendingPathComponent("test.pdf")

        let (srcURL, file) = try makeSourceFile()
        let planned = PlannedItem(
            file: file,
            action: .move(destination: destURL, reason: "rule matched"),
            confidence: .high,
            reason: "rule matched",
            appliedRuleIds: ["rule-1", "rule-2"]
        )

        let records = try await executor.execute([planned], batchId: batchId)

        XCTAssertEqual(records.count, 1)
        let record = records.first!
        XCTAssertEqual(record.batchId, batchId)
        XCTAssertEqual(record.sourceURL, srcURL)
        XCTAssertEqual(record.destinationURL, destURL)
        XCTAssertEqual(record.reason, "rule matched")
        XCTAssertEqual(record.ruleIds, ["rule-1", "rule-2"])
        XCTAssertNil(record.undoneAt)
    }
}

// MARK: - Test Errors

private enum TestError: Error {
    case recordFailed
}
