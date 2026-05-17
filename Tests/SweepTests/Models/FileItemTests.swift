import XCTest
@testable import Sweep

final class FileItemTests: XCTestCase {

    private func makeItem(
        url: URL = URL(fileURLWithPath: "/Users/test/Downloads/MyDocument.PDF"),
        size: Int64 = 1024,
        createdAt: Date = Date(timeIntervalSince1970: 1_716_000_000),
        modifiedAt: Date = Date(timeIntervalSince1970: 1_716_086_400),
        mimeType: String? = "application/pdf",
        sha256Prefix: String? = "abc123"
    ) -> FileItem {
        FileItem(
            url: url,
            size: size,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            mimeType: mimeType,
            sha256Prefix: sha256Prefix
        )
    }

    func testFilename() {
        let item = makeItem(url: URL(fileURLWithPath: "/Users/test/Downloads/MyDocument.pdf"))
        XCTAssertEqual(item.filename, "MyDocument.pdf")
    }

    func testFilenameWithNestedPath() {
        let item = makeItem(url: URL(fileURLWithPath: "/Users/test/Downloads/subdir/report.txt"))
        XCTAssertEqual(item.filename, "report.txt")
    }

    func testFileExtensionIsLowercased() {
        let item = makeItem(url: URL(fileURLWithPath: "/Users/test/Downloads/MyDocument.PDF"))
        XCTAssertEqual(item.fileExtension, "pdf")
    }

    func testFileExtensionAlreadyLowercase() {
        let item = makeItem(url: URL(fileURLWithPath: "/Users/test/Downloads/invoice.pdf"))
        XCTAssertEqual(item.fileExtension, "pdf")
    }

    func testFileExtensionMixedCase() {
        let item = makeItem(url: URL(fileURLWithPath: "/Users/test/Downloads/image.PNG"))
        XCTAssertEqual(item.fileExtension, "png")
    }

    func testFileExtensionNoExtension() {
        let item = makeItem(url: URL(fileURLWithPath: "/Users/test/Downloads/Makefile"))
        XCTAssertEqual(item.fileExtension, "")
    }

    func testAgeInDaysIsPositive() {
        // Created 1 day ago
        let item = makeItem(createdAt: Date(timeIntervalSinceNow: -86400))
        XCTAssertGreaterThan(item.ageInDays, 0)
    }

    func testAgeInDaysApproximatelyCorrect() {
        // Created ~7 days ago
        let sevenDaysAgo = Date(timeIntervalSinceNow: -7 * 86400)
        let item = makeItem(createdAt: sevenDaysAgo)
        XCTAssertEqual(item.ageInDays, 7.0, accuracy: 0.01)
    }

    func testAgeInDaysForRecentFile() {
        // Created 1 hour ago — age should be small but positive
        let item = makeItem(createdAt: Date(timeIntervalSinceNow: -3600))
        XCTAssertGreaterThan(item.ageInDays, 0)
        XCTAssertLessThan(item.ageInDays, 1)
    }

    func testCodableRoundTrip() throws {
        let original = makeItem(
            url: URL(fileURLWithPath: "/Users/test/Downloads/invoice_may.pdf"),
            size: 204800,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            modifiedAt: Date(timeIntervalSince1970: 1_700_100_000),
            mimeType: "application/pdf",
            sha256Prefix: "deadbeef"
        )

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(FileItem.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCodableRoundTripWithNilOptionals() throws {
        let original = makeItem(mimeType: nil, sha256Prefix: nil)

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(FileItem.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.mimeType)
        XCTAssertNil(decoded.sha256Prefix)
    }

    func testCodableRoundTripPreservesAllFields() throws {
        let createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        let modifiedAt = Date(timeIntervalSince1970: 1_600_500_000)
        let original = FileItem(
            url: URL(fileURLWithPath: "/tmp/test.dmg"),
            size: 999_999,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            mimeType: "application/x-apple-diskimage",
            sha256Prefix: "cafebabe"
        )

        let data = try SweepJSON.encoder.encode(original)
        let decoded = try SweepJSON.decoder.decode(FileItem.self, from: data)

        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.size, original.size)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(decoded.modifiedAt.timeIntervalSince1970, original.modifiedAt.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(decoded.mimeType, original.mimeType)
        XCTAssertEqual(decoded.sha256Prefix, original.sha256Prefix)
    }
}
