import XCTest
@testable import Sweep

final class PlannedItemTests: XCTestCase {

    private func makeFileItem(
        path: String = "/Users/test/Downloads/invoice_may.pdf",
        size: Int64 = 204800,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        modifiedAt: Date = Date(timeIntervalSince1970: 1_700_100_000),
        mimeType: String? = "application/pdf"
    ) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: path),
            size: size,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            mimeType: mimeType
        )
    }

    private func makePlannedItem(
        file: FileItem? = nil,
        action: ProposedAction = .archive(reason: "Old installer"),
        confidence: ConfidenceTier = .high,
        reason: String = "DMG after installation",
        appliedRuleIds: [String] = ["dmg-after-install"]
    ) -> PlannedItem {
        PlannedItem(
            file: file ?? makeFileItem(),
            action: action,
            confidence: confidence,
            reason: reason,
            appliedRuleIds: appliedRuleIds
        )
    }

    // MARK: - Initialization

    func testInitWithDefaultAppliedRuleIds() {
        let item = PlannedItem(
            file: makeFileItem(),
            action: .keep(reason: "Actively used"),
            confidence: .medium,
            reason: "User is actively working on this"
        )
        XCTAssertEqual(item.appliedRuleIds, [])
    }

    func testInitStoresAllFields() {
        let file = makeFileItem()
        let action = ProposedAction.move(
            destination: URL(fileURLWithPath: "/Users/test/Documents/Finance"),
            reason: "Invoice file"
        )
        let ruleIds = ["invoices-pdf", "pdf-rule"]
        let item = PlannedItem(
            file: file,
            action: action,
            confidence: .high,
            reason: "Looks like an invoice",
            appliedRuleIds: ruleIds
        )

        XCTAssertEqual(item.file, file)
        XCTAssertEqual(item.action, action)
        XCTAssertEqual(item.confidence, .high)
        XCTAssertEqual(item.reason, "Looks like an invoice")
        XCTAssertEqual(item.appliedRuleIds, ruleIds)
    }

    // MARK: - Codable round-trips

    func testCodableRoundTripWithArchiveAction() throws {
        let original = makePlannedItem(
            action: .archive(reason: "Old DMG installer"),
            confidence: .high,
            reason: "DMG after installation",
            appliedRuleIds: ["dmg-after-install"]
        )

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripWithMoveAction() throws {
        let destination = URL(fileURLWithPath: "/Users/test/Documents/Finance/Invoices")
        let original = PlannedItem(
            file: makeFileItem(path: "/Users/test/Downloads/invoice_may.pdf"),
            action: .move(destination: destination, reason: "Invoice file"),
            confidence: .medium,
            reason: "Filename contains 'invoice'",
            appliedRuleIds: ["invoices-pdf"]
        )

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripWithReviewLaterAction() throws {
        let original = PlannedItem(
            file: makeFileItem(path: "/Users/test/Downloads/Screenshot 2026-05-01.png"),
            action: .reviewLater(reason: "Screenshot, might want to keep"),
            confidence: .low,
            reason: "Unclear purpose",
            appliedRuleIds: ["screenshots"]
        )

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripWithKeepAction() throws {
        let original = PlannedItem(
            file: makeFileItem(path: "/Users/test/Downloads/project.zip"),
            action: .keep(reason: "Recent download, might be needed"),
            confidence: .low,
            reason: "Very recent file",
            appliedRuleIds: []
        )

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripPreservesFileFields() throws {
        let createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        let modifiedAt = Date(timeIntervalSince1970: 1_600_500_000)
        let file = FileItem(
            url: URL(fileURLWithPath: "/Users/test/Downloads/report.pdf"),
            size: 512_000,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            mimeType: "application/pdf",
            sha256Prefix: "deadbeef"
        )
        let original = PlannedItem(
            file: file,
            action: .archive(reason: "Old report"),
            confidence: .high,
            reason: "Report from 2020",
            appliedRuleIds: ["invoices-pdf"]
        )

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)

        XCTAssertEqual(decoded.file.url, file.url)
        XCTAssertEqual(decoded.file.size, file.size)
        XCTAssertEqual(decoded.file.mimeType, file.mimeType)
        XCTAssertEqual(decoded.file.sha256Prefix, file.sha256Prefix)
        XCTAssertEqual(decoded.file.createdAt.timeIntervalSince1970, createdAt.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(decoded.file.modifiedAt.timeIntervalSince1970, modifiedAt.timeIntervalSince1970, accuracy: 1.0)
    }

    func testCodableRoundTripPreservesConfidence() throws {
        for confidence in [ConfidenceTier.low, .medium, .high] {
            let original = makePlannedItem(confidence: confidence)
            let data = try SweepJSON.encoder.encode(original)
            let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)
            XCTAssertEqual(decoded.confidence, confidence, "Confidence tier '\(confidence.rawValue)' should survive round-trip")
        }
    }

    func testCodableRoundTripPreservesAppliedRuleIds() throws {
        let ruleIds = ["dmg-after-install", "screenshots", "invoices-pdf"]
        let original = makePlannedItem(appliedRuleIds: ruleIds)

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)

        XCTAssertEqual(decoded.appliedRuleIds, ruleIds)
    }

    func testCodableRoundTripWithEmptyRuleIds() throws {
        let original = makePlannedItem(appliedRuleIds: [])

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(PlannedItem.self, from: data)

        XCTAssertEqual(decoded.appliedRuleIds, [])
    }

    // MARK: - Equatable

    func testEqualPlannedItems() {
        let item1 = makePlannedItem()
        let item2 = makePlannedItem()
        XCTAssertEqual(item1, item2)
    }

    func testUnequalWhenConfidenceDiffers() {
        let item1 = makePlannedItem(confidence: .high)
        let item2 = makePlannedItem(confidence: .low)
        XCTAssertNotEqual(item1, item2)
    }

    func testUnequalWhenActionDiffers() {
        let item1 = makePlannedItem(action: .archive(reason: "Old DMG"))
        let item2 = makePlannedItem(action: .keep(reason: "Needed"))
        XCTAssertNotEqual(item1, item2)
    }

    func testUnequalWhenReasonDiffers() {
        let item1 = makePlannedItem(reason: "Reason A")
        let item2 = makePlannedItem(reason: "Reason B")
        XCTAssertNotEqual(item1, item2)
    }
}
