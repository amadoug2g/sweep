import XCTest
@testable import Sweep

final class UndoRecordTests: XCTestCase {

    private let fixedBatchId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let fixedId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let fixedTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
    private let fixedSource = URL(fileURLWithPath: "/Users/test/Downloads/installer.dmg")
    private let fixedDestination = URL(fileURLWithPath: "/Users/test/Documents/Sweep/Archive/2026-05/installer.dmg")

    private func makeRecord(
        id: UUID? = nil,
        timestamp: Date? = nil,
        batchId: UUID? = nil,
        sourceURL: URL? = nil,
        destinationURL: URL? = nil,
        reason: String = "DMG after installation",
        ruleIds: [String] = ["dmg-after-install"]
    ) -> UndoRecord {
        UndoRecord(
            id: id ?? fixedId,
            timestamp: timestamp ?? fixedTimestamp,
            batchId: batchId ?? fixedBatchId,
            sourceURL: sourceURL ?? fixedSource,
            destinationURL: destinationURL ?? fixedDestination,
            reason: reason,
            ruleIds: ruleIds
        )
    }

    // MARK: - isUndone

    func testIsUndoneIsFalseWhenUndoneAtIsNil() {
        let record = makeRecord()
        XCTAssertFalse(record.isUndone)
    }

    func testIsUndoneIsTrueWhenUndoneAtIsSet() {
        var record = makeRecord()
        record.undoneAt = Date()
        XCTAssertTrue(record.isUndone)
    }

    func testUndoneAtStartsNil() {
        let record = makeRecord()
        XCTAssertNil(record.undoneAt)
    }

    func testUndoneAtCanBeSetToADate() {
        var record = makeRecord()
        let undoneDate = Date(timeIntervalSince1970: 1_700_500_000)
        record.undoneAt = undoneDate
        XCTAssertEqual(record.undoneAt, undoneDate)
    }

    func testUndoneAtCanBeCleared() {
        var record = makeRecord()
        record.undoneAt = Date()
        XCTAssertTrue(record.isUndone)
        record.undoneAt = nil
        XCTAssertFalse(record.isUndone)
    }

    // MARK: - Default init values

    func testDefaultInitGeneratesId() {
        let record = UndoRecord(
            batchId: fixedBatchId,
            sourceURL: fixedSource,
            destinationURL: fixedDestination,
            reason: "test"
        )
        // Just verify it's set (non-nil UUID struct always has a value)
        XCTAssertNotEqual(record.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    func testDefaultInitTimestampIsRecent() {
        let before = Date()
        let record = UndoRecord(
            batchId: fixedBatchId,
            sourceURL: fixedSource,
            destinationURL: fixedDestination,
            reason: "test"
        )
        let after = Date()
        XCTAssertGreaterThanOrEqual(record.timestamp, before)
        XCTAssertLessThanOrEqual(record.timestamp, after)
    }

    func testDefaultInitRuleIdsIsEmpty() {
        let record = UndoRecord(
            batchId: fixedBatchId,
            sourceURL: fixedSource,
            destinationURL: fixedDestination,
            reason: "test"
        )
        XCTAssertEqual(record.ruleIds, [])
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesId() throws {
        let original = makeRecord()
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
    }

    func testCodableRoundTripPreservesBatchId() throws {
        let original = makeRecord()
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.batchId, original.batchId)
    }

    func testCodableRoundTripPreservesTimestamp() throws {
        let original = makeRecord()
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, original.timestamp.timeIntervalSince1970, accuracy: 1.0)
    }

    func testCodableRoundTripPreservesSourceURL() throws {
        let original = makeRecord()
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.sourceURL, original.sourceURL)
    }

    func testCodableRoundTripPreservesDestinationURL() throws {
        let original = makeRecord()
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.destinationURL, original.destinationURL)
    }

    func testCodableRoundTripPreservesReason() throws {
        let original = makeRecord(reason: "Moved invoice to Finance folder")
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.reason, original.reason)
    }

    func testCodableRoundTripPreservesRuleIds() throws {
        let original = makeRecord(ruleIds: ["dmg-after-install", "screenshots"])
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.ruleIds, original.ruleIds)
    }

    func testCodableRoundTripPreservesUndoneAtNil() throws {
        let original = makeRecord()
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertNil(decoded.undoneAt)
        XCTAssertFalse(decoded.isUndone)
    }

    func testCodableRoundTripPreservesUndoneAtWhenSet() throws {
        var original = makeRecord()
        let undoneDate = Date(timeIntervalSince1970: 1_700_500_000)
        original.undoneAt = undoneDate

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)

        XCTAssertTrue(decoded.isUndone)
        XCTAssertNotNil(decoded.undoneAt)
        XCTAssertEqual(decoded.undoneAt!.timeIntervalSince1970, undoneDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testCodableRoundTripWithEmptyRuleIds() throws {
        let original = makeRecord(ruleIds: [])
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)
        XCTAssertEqual(decoded.ruleIds, [])
    }

    func testCodableRoundTripFullRecord() throws {
        var original = makeRecord(
            id: fixedId,
            timestamp: fixedTimestamp,
            batchId: fixedBatchId,
            sourceURL: fixedSource,
            destinationURL: fixedDestination,
            reason: "DMG installed, archiving",
            ruleIds: ["dmg-after-install"]
        )
        original.undoneAt = nil

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(UndoRecord.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.batchId, original.batchId)
        XCTAssertEqual(decoded.sourceURL, original.sourceURL)
        XCTAssertEqual(decoded.destinationURL, original.destinationURL)
        XCTAssertEqual(decoded.reason, original.reason)
        XCTAssertEqual(decoded.ruleIds, original.ruleIds)
        XCTAssertNil(decoded.undoneAt)
        XCTAssertFalse(decoded.isUndone)
    }

    // MARK: - Identifiable

    func testIdIsAccessible() {
        let record = makeRecord(id: fixedId)
        XCTAssertEqual(record.id, fixedId)
    }

    func testTwoRecordsWithDifferentIdsHaveDifferentIds() {
        let id1 = UUID()
        let id2 = UUID()
        let record1 = makeRecord(id: id1)
        let record2 = makeRecord(id: id2)
        XCTAssertNotEqual(record1.id, record2.id)
    }
}
