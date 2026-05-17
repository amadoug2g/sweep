import XCTest
@testable import Sweep

final class UndoLogTests: XCTestCase {

    private var tempDir: URL!
    private var logFile: URL!
    private var undoLog: UndoLog!

    // Source & destination scratch space for file-move tests.
    private var srcDir: URL!
    private var dstDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepUndoLogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        logFile = tempDir.appendingPathComponent("undo.jsonl")
        undoLog = UndoLog(fileURL: logFile)

        srcDir = tempDir.appendingPathComponent("src", isDirectory: true)
        dstDir = tempDir.appendingPathComponent("dst", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a real file at srcDir/<name> and a UndoRecord that points from src to dst.
    private func makeRecordWithFile(
        named name: String = "file.pdf",
        batchId: UUID = UUID(),
        timestamp: Date = Date()
    ) throws -> (UndoRecord, URL, URL) {
        let src = srcDir.appendingPathComponent(name)
        let dst = dstDir.appendingPathComponent(name)
        try "content".write(to: src, atomically: true, encoding: .utf8)
        let record = UndoRecord(
            timestamp: timestamp,
            batchId: batchId,
            sourceURL: src,
            destinationURL: dst,
            reason: "test"
        )
        return (record, src, dst)
    }

    /// Moves a file from src to dst manually (simulating what ActionExecutor does).
    private func moveFile(from src: URL, to dst: URL) throws {
        try FileManager.default.moveItem(at: src, to: dst)
    }

    // MARK: - record + recentRecords

    func testRecordThenRecentRecordsReturnsTheRecord() throws {
        let (record, _, _) = try makeRecordWithFile()
        try undoLog.record(record)

        let recent = undoLog.recentRecords(limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.id, record.id)
    }

    func testRecentRecordsRespectsLimit() throws {
        for i in 0..<5 {
            let (record, _, _) = try makeRecordWithFile(named: "file\(i).pdf")
            try undoLog.record(record)
        }
        let recent = undoLog.recentRecords(limit: 3)
        XCTAssertEqual(recent.count, 3)
    }

    func testRecentRecordsIsSortedNewestFirst() throws {
        let batchId = UUID()
        var ids: [UUID] = []
        for i in 0..<3 {
            let (record, _, _) = try makeRecordWithFile(
                named: "file\(i).pdf",
                batchId: batchId,
                timestamp: Date(timeIntervalSinceNow: Double(i))
            )
            try undoLog.record(record)
            ids.append(record.id)
        }

        let recent = undoLog.recentRecords(limit: 10)
        // Last-inserted (highest timestamp) should come first.
        XCTAssertEqual(recent.first?.id, ids.last)
    }

    func testRecordPersistsToDisk() throws {
        let (record, _, _) = try makeRecordWithFile()
        try undoLog.record(record)

        // Create a fresh log pointing at the same file.
        let freshLog = UndoLog(fileURL: logFile)
        let recent = freshLog.recentRecords(limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.id, record.id)
    }

    // MARK: - undo

    func testUndoMovesFileBackAndMarksUndoneAt() throws {
        let (record, src, dst) = try makeRecordWithFile()
        // Simulate the executor: move file to dst first.
        try moveFile(from: src, to: dst)
        try undoLog.record(record)

        let undone = try undoLog.undo(id: record.id)

        XCTAssertNotNil(undone.undoneAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: src.path), "File should be back at source")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dst.path), "File should no longer be at destination")
    }

    func testUndoMarksRecordInPersistedFile() throws {
        let (record, src, dst) = try makeRecordWithFile()
        try moveFile(from: src, to: dst)
        try undoLog.record(record)

        try undoLog.undo(id: record.id)

        let freshLog = UndoLog(fileURL: logFile)
        let recent = freshLog.recentRecords(limit: 10)
        XCTAssertNotNil(recent.first?.undoneAt)
    }

    func testUndoThrowsWhenFileNotAtDestination() throws {
        let (record, _, _) = try makeRecordWithFile()
        // Don't move the file — dst doesn't exist.
        try undoLog.record(record)

        XCTAssertThrowsError(try undoLog.undo(id: record.id)) { error in
            guard case UndoError.fileNotAtDestination = error else {
                XCTFail("Expected fileNotAtDestination, got \(error)")
                return
            }
        }
    }

    func testUndoThrowsForUnknownId() throws {
        XCTAssertThrowsError(try undoLog.undo(id: UUID())) { error in
            guard case UndoError.recordNotFound = error else {
                XCTFail("Expected recordNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - undoLastBatch

    func testUndoLastBatchUndoesAllMatchingRecords() throws {
        let batchId = UUID()

        // Two files in the same batch.
        let (r1, src1, dst1) = try makeRecordWithFile(named: "a.pdf", batchId: batchId)
        let (r2, src2, dst2) = try makeRecordWithFile(named: "b.pdf", batchId: batchId)

        try moveFile(from: src1, to: dst1)
        try moveFile(from: src2, to: dst2)
        try undoLog.record(r1)
        try undoLog.record(r2)

        let undone = try undoLog.undoLastBatch(batchId: batchId)

        XCTAssertEqual(undone.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: src1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: src2.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dst1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dst2.path))
    }

    func testUndoLastBatchDoesNotUndoAlreadyUndoneRecords() throws {
        let batchId = UUID()
        let (record, src, dst) = try makeRecordWithFile(batchId: batchId)
        try moveFile(from: src, to: dst)
        try undoLog.record(record)

        // First undo.
        _ = try undoLog.undoLastBatch(batchId: batchId)
        // Move back to dst to simulate re-execution.
        try moveFile(from: src, to: dst)

        // Second undo — should be empty because the record is already undone.
        let undone = try undoLog.undoLastBatch(batchId: batchId)
        XCTAssertTrue(undone.isEmpty)
    }

    func testUndoLastBatchReturnsEmptyForUnknownBatchId() throws {
        let undone = try undoLog.undoLastBatch(batchId: UUID())
        XCTAssertTrue(undone.isEmpty)
    }

    // MARK: - purgeOlderThan

    func testPurgeOlderThanRemovesOldUndoneRecords() throws {
        // A record from 10 days ago that has been undone.
        let oldDate = Date().addingTimeInterval(-10 * 86_400)
        let (oldRecord, src, dst) = try makeRecordWithFile(
            named: "old.pdf",
            timestamp: oldDate
        )
        try moveFile(from: src, to: dst)
        try undoLog.record(oldRecord)
        // Mark as undone by setting undoneAt directly via undo.
        try moveFile(from: dst, to: src)  // restore so undo can move it back
        // Manually move to dst again for the undo call.
        try moveFile(from: src, to: dst)
        _ = try undoLog.undo(id: oldRecord.id)

        // A recent record (should be kept).
        let (recentRecord, _, _) = try makeRecordWithFile(named: "recent.pdf")
        try undoLog.record(recentRecord)

        try undoLog.purgeOlderThan(days: 7)

        let remaining = undoLog.recentRecords(limit: 100)
        XCTAssertFalse(remaining.contains(where: { $0.id == oldRecord.id }), "Old undone record should be purged")
        XCTAssertTrue(remaining.contains(where: { $0.id == recentRecord.id }), "Recent record should remain")
    }

    func testPurgeOlderThanKeepsOldNonUndoneRecords() throws {
        // An old record that hasn't been undone yet — should NOT be purged (within 90 days).
        let oldDate = Date().addingTimeInterval(-10 * 86_400)
        let (oldRecord, _, _) = try makeRecordWithFile(named: "old_kept.pdf", timestamp: oldDate)
        try undoLog.record(oldRecord)

        try undoLog.purgeOlderThan(days: 7)

        let remaining = undoLog.recentRecords(limit: 100)
        XCTAssertTrue(remaining.contains(where: { $0.id == oldRecord.id }))
    }
}
