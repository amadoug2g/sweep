import XCTest
@testable import Sweep

final class ContextStoreTests: XCTestCase {

    private var tempDir: URL!
    private var store: ContextStore!

    override func setUp() {
        super.setUp()
        // Use a unique temp subdirectory per test so tests don't share state.
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepContextStoreTests-\(UUID().uuidString)", isDirectory: true)
        // Intentionally do NOT create the directory — ContextStore must create it.
        store = ContextStore(fileURL: tempDir.appendingPathComponent("context.json"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        store = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - First load on missing file returns .seed

    func testFirstLoadReturnsSeedWhenFileAbsent() throws {
        let profile = try store.load()
        // seed has three rules by definition
        XCTAssertEqual(profile.rules.count, ContextProfile.seed.rules.count)
        XCTAssertEqual(profile.folderMap, ContextProfile.seed.folderMap)
    }

    // MARK: - First load also persists the seed so the file now exists

    func testFirstLoadCreatesSeedFile() throws {
        _ = try store.load()
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    // MARK: - Save then load round-trips all fields

    func testSaveThenLoadRoundTripsAllFields() throws {
        var profile = ContextProfile.seed
        profile.version = 2
        profile.userFacts = ["I like PDFs", "Keep receipts for 7 years"]
        profile.folderMap["invoices"] = "/Users/demo/Documents/Finance"
        profile.rules.append(Rule(id: "test-rule", description: "A test rule", examples: ["foo.txt"], createdBy: .user))
        profile.preferences = SweepPreferences(
            scanIntervalSeconds: 1800,
            autoActEnabled: true,
            stagingFolderPath: "/tmp/staging",
            archiveFolderPath: "/tmp/archive"
        )
        // Use a fixed date so we can compare it after decode.
        let fixedDate = ISO8601DateFormatter().date(from: "2026-05-17T12:00:00Z")!
        profile.lastUpdated = fixedDate

        try store.save(profile)
        let loaded = try store.load()

        XCTAssertEqual(loaded.version, 2)
        XCTAssertEqual(loaded.userFacts, ["I like PDFs", "Keep receipts for 7 years"])
        XCTAssertEqual(loaded.folderMap["invoices"], "/Users/demo/Documents/Finance")
        XCTAssertEqual(loaded.rules.last?.id, "test-rule")
        XCTAssertEqual(loaded.preferences.scanIntervalSeconds, 1800)
        XCTAssertTrue(loaded.preferences.autoActEnabled)
        XCTAssertEqual(loaded.lastUpdated, fixedDate)
    }

    // MARK: - Atomic write — re-reading after save produces identical data

    func testAtomicWriteDoesNotCorruptOnReRead() throws {
        let profile = ContextProfile.seed
        try store.save(profile)

        // Read the raw bytes and confirm valid JSON.
        let data = try Data(contentsOf: store.fileURL)
        XCTAssertNoThrow(try SweepJSON.decoder.decode(ContextProfile.self, from: data))
    }

    // MARK: - Directory created if missing

    func testDirectoryIsCreatedIfMissing() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path),
                       "Precondition: temp dir must NOT exist before the test")
        _ = try store.load()
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
    }

    // MARK: - Saving creates the file even when it didn't exist

    func testSaveCreatesFileWhenAbsent() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        try store.save(.seed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    // MARK: - Multiple saves overwrite cleanly

    func testMultipleSavesOverwriteCleanly() throws {
        var first = ContextProfile.seed
        first.version = 10
        try store.save(first)

        var second = ContextProfile.seed
        second.version = 11
        try store.save(second)

        let loaded = try store.load()
        XCTAssertEqual(loaded.version, 11)
    }
}
