import XCTest
@testable import Sweep

final class ProposedActionTests: XCTestCase {

    // MARK: - reason property

    func testReasonForMove() {
        let action = ProposedAction.move(destination: URL(fileURLWithPath: "/tmp/dest"), reason: "Belongs in projects")
        XCTAssertEqual(action.reason, "Belongs in projects")
    }

    func testReasonForArchive() {
        let action = ProposedAction.archive(reason: "Old installer no longer needed")
        XCTAssertEqual(action.reason, "Old installer no longer needed")
    }

    func testReasonForReviewLater() {
        let action = ProposedAction.reviewLater(reason: "Not sure about this one")
        XCTAssertEqual(action.reason, "Not sure about this one")
    }

    func testReasonForKeep() {
        let action = ProposedAction.keep(reason: "Actively using this file")
        XCTAssertEqual(action.reason, "Actively using this file")
    }

    // MARK: - isAutoActable

    func testIsAutoActableForMove() {
        let action = ProposedAction.move(destination: URL(fileURLWithPath: "/tmp/dest"), reason: "reason")
        XCTAssertTrue(action.isAutoActable)
    }

    func testIsAutoActableForArchive() {
        let action = ProposedAction.archive(reason: "reason")
        XCTAssertTrue(action.isAutoActable)
    }

    func testIsNotAutoActableForReviewLater() {
        let action = ProposedAction.reviewLater(reason: "reason")
        XCTAssertFalse(action.isAutoActable)
    }

    func testIsNotAutoActableForKeep() {
        let action = ProposedAction.keep(reason: "reason")
        XCTAssertFalse(action.isAutoActable)
    }

    // MARK: - Codable round-trips

    func testCodableRoundTripMove() throws {
        let destination = URL(fileURLWithPath: "/Users/test/Documents/Projects")
        let original = ProposedAction.move(destination: destination, reason: "Project file")

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ProposedAction.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripMovePreservesDestinationPath() throws {
        let destinationPath = "/Users/test/Documents/Finance/Invoices"
        let original = ProposedAction.move(destination: URL(fileURLWithPath: destinationPath), reason: "Invoice file")

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ProposedAction.self, from: data)

        if case .move(let decodedDest, _) = decoded {
            XCTAssertEqual(decodedDest.path, destinationPath)
        } else {
            XCTFail("Expected .move action after decoding")
        }
    }

    func testCodableRoundTripArchive() throws {
        let original = ProposedAction.archive(reason: "DMG after installation")

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ProposedAction.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripReviewLater() throws {
        let original = ProposedAction.reviewLater(reason: "Uncertain category")

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ProposedAction.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripKeep() throws {
        let original = ProposedAction.keep(reason: "Active project file")

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ProposedAction.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Reason is preserved through Codable

    func testCodablePreservesReason() throws {
        let expectedReason = "Invoice from May 2026"
        let original = ProposedAction.archive(reason: expectedReason)

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ProposedAction.self, from: data)

        XCTAssertEqual(decoded.reason, expectedReason)
    }
}
