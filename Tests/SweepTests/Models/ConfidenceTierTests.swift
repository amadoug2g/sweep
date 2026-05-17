import XCTest
@testable import Sweep

final class ConfidenceTierTests: XCTestCase {

    // MARK: - Comparable ordering

    func testLowLessThanMedium() {
        XCTAssertLessThan(ConfidenceTier.low, ConfidenceTier.medium)
    }

    func testMediumLessThanHigh() {
        XCTAssertLessThan(ConfidenceTier.medium, ConfidenceTier.high)
    }

    func testLowLessThanHigh() {
        XCTAssertLessThan(ConfidenceTier.low, ConfidenceTier.high)
    }

    func testHighNotLessThanMedium() {
        XCTAssertFalse(ConfidenceTier.high < ConfidenceTier.medium)
    }

    func testHighNotLessThanLow() {
        XCTAssertFalse(ConfidenceTier.high < ConfidenceTier.low)
    }

    func testMediumNotLessThanLow() {
        XCTAssertFalse(ConfidenceTier.medium < ConfidenceTier.low)
    }

    func testEqualityLow() {
        XCTAssertEqual(ConfidenceTier.low, ConfidenceTier.low)
    }

    func testEqualityMedium() {
        XCTAssertEqual(ConfidenceTier.medium, ConfidenceTier.medium)
    }

    func testEqualityHigh() {
        XCTAssertEqual(ConfidenceTier.high, ConfidenceTier.high)
    }

    func testSortedOrder() {
        let tiers: [ConfidenceTier] = [.high, .low, .medium]
        let sorted = tiers.sorted()
        XCTAssertEqual(sorted, [.low, .medium, .high])
    }

    // MARK: - Codable round-trips

    func testCodableRoundTripLow() throws {
        let original = ConfidenceTier.low
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ConfidenceTier.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripMedium() throws {
        let original = ConfidenceTier.medium
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ConfidenceTier.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripHigh() throws {
        let original = ConfidenceTier.high
        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(ConfidenceTier.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testRawValueLow() {
        XCTAssertEqual(ConfidenceTier.low.rawValue, "low")
    }

    func testRawValueMedium() {
        XCTAssertEqual(ConfidenceTier.medium.rawValue, "medium")
    }

    func testRawValueHigh() {
        XCTAssertEqual(ConfidenceTier.high.rawValue, "high")
    }
}
