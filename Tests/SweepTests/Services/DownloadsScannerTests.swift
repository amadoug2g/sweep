import XCTest
@testable import Sweep

final class DownloadsScannerTests: XCTestCase {

    // Temp directory that acts as a fake Downloads folder.
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // Resolve symlinks AFTER creation (full path must exist) so /var → /private/var
        // is normalised and URL comparisons against scanner results always match.
        tempDir = tempDir.resolvingSymlinksInPath()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a file at `tempDir/<name>` with the given modification date.
    @discardableResult
    private func makeFile(
        named name: String,
        modifiedAt: Date = Date().addingTimeInterval(-120)  // 2 min old by default
    ) throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try "content".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: modifiedAt],
            ofItemAtPath: url.path
        )
        return url
    }

    private func makeScanner(minimumAgeSeconds: TimeInterval = 60) -> DownloadsScanner {
        DownloadsScanner(downloadsURL: tempDir, minimumAgeSeconds: minimumAgeSeconds)
    }

    // MARK: - Tests

    func testCrdownloadFilesAreSkipped() async throws {
        try makeFile(named: "video.crdownload")
        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 0)
        XCTAssertEqual(report.skippedCount, 1)
    }

    func testPartFilesAreSkipped() async throws {
        try makeFile(named: "archive.part")
        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 0)
        XCTAssertEqual(report.skippedCount, 1)
    }

    func testDownloadExtensionFilesAreSkipped() async throws {
        try makeFile(named: "installer.download")
        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 0)
        XCTAssertEqual(report.skippedCount, 1)
    }

    func testTmpFilesAreSkipped() async throws {
        try makeFile(named: "temp.tmp")
        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 0)
        XCTAssertEqual(report.skippedCount, 1)
    }

    func testHiddenFilesAreSkipped() async throws {
        try makeFile(named: ".DS_Store")
        try makeFile(named: ".hidden_file.txt")
        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 0)
        XCTAssertEqual(report.skippedCount, 2)
    }

    func testFilesModifiedTooRecentlyAreSkipped() async throws {
        // Modified only 10 seconds ago; minimumAge is 60 seconds.
        try makeFile(named: "fresh.pdf", modifiedAt: Date().addingTimeInterval(-10))
        let report = try await makeScanner(minimumAgeSeconds: 60).scan()
        XCTAssertEqual(report.items.count, 0)
        XCTAssertEqual(report.skippedCount, 1)
    }

    func testDirectoriesAreSkipped() async throws {
        let subdir = tempDir.appendingPathComponent("MyFolder", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 0)
        XCTAssertEqual(report.skippedCount, 1)
    }

    func testValidPdfReturnsOneFileItemWithCorrectFilename() async throws {
        let url = try makeFile(named: "report.pdf")
        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(report.items.first?.filename, "report.pdf")
        // Resolve symlinks on both sides — macOS scanner resolves /var→/private/var
        XCTAssertEqual(report.items.first?.url.resolvingSymlinksInPath(), url.resolvingSymlinksInPath())
        XCTAssertEqual(report.skippedCount, 0)
    }

    func testSkippedCountReflectsAllFilteredFiles() async throws {
        // 1 valid file, 3 filtered
        try makeFile(named: "good.pdf")
        try makeFile(named: ".hidden")
        try makeFile(named: "partial.crdownload")
        try makeFile(named: "new.txt", modifiedAt: Date().addingTimeInterval(-5))

        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(report.skippedCount, 3)
    }

    func testFileSizeIsPopulated() async throws {
        let url = tempDir.appendingPathComponent("sized.txt")
        let content = String(repeating: "x", count: 1024)
        try content.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-120)],
            ofItemAtPath: url.path
        )

        let report = try await makeScanner().scan()
        XCTAssertEqual(report.items.count, 1)
        XCTAssertGreaterThan(report.items.first?.size ?? 0, 0)
    }

    func testScanReportTimestampIsApproxNow() async throws {
        let before = Date()
        let report = try await makeScanner().scan()
        let after = Date()
        XCTAssertGreaterThanOrEqual(report.scannedAt, before)
        XCTAssertLessThanOrEqual(report.scannedAt, after)
    }

    func testEmptyDirectoryReturnsEmptyReport() async throws {
        let report = try await makeScanner().scan()
        XCTAssertTrue(report.items.isEmpty)
        XCTAssertEqual(report.skippedCount, 0)
    }
}
