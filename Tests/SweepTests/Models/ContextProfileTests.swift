import XCTest
@testable import Sweep

final class ContextProfileTests: XCTestCase {

    // MARK: - Static instances

    func testSeedHasThreeRules() {
        XCTAssertEqual(ContextProfile.seed.rules.count, 3)
    }

    func testSeedRuleIds() {
        let ids = ContextProfile.seed.rules.map(\.id)
        XCTAssertTrue(ids.contains("dmg-after-install"))
        XCTAssertTrue(ids.contains("invoices-pdf"))
        XCTAssertTrue(ids.contains("screenshots"))
    }

    func testSeedAllRulesAreOriginSeed() {
        for rule in ContextProfile.seed.rules {
            XCTAssertEqual(rule.createdBy, .seed, "Rule '\(rule.id)' should have .seed origin")
        }
    }

    func testSeedHasFolderMap() {
        XCTAssertFalse(ContextProfile.seed.folderMap.isEmpty)
        XCTAssertNotNil(ContextProfile.seed.folderMap["review"])
        XCTAssertNotNil(ContextProfile.seed.folderMap["archive"])
    }

    func testEmptyHasZeroRules() {
        XCTAssertEqual(ContextProfile.empty.rules.count, 0)
    }

    func testEmptyHasEmptyFolderMap() {
        XCTAssertTrue(ContextProfile.empty.folderMap.isEmpty)
    }

    func testEmptyHasEmptyUserFacts() {
        XCTAssertTrue(ContextProfile.empty.userFacts.isEmpty)
    }

    func testEmptyAutoActIsDisabled() {
        XCTAssertFalse(ContextProfile.empty.preferences.autoActEnabled)
    }

    func testEmptyVersionIsOne() {
        XCTAssertEqual(ContextProfile.empty.version, 1)
    }

    func testSeedVersionIsOne() {
        XCTAssertEqual(ContextProfile.seed.version, 1)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTripPreservesVersion() throws {
        let profile = ContextProfile(
            version: 42,
            userFacts: ["Fact 1", "Fact 2"],
            folderMap: ["invoices": "/Users/test/Documents/Finance"],
            rules: [Rule(id: "test-rule", description: "A test rule", examples: ["example.txt"], createdBy: .user, weight: 1.5)],
            preferences: SweepPreferences(
                scanIntervalSeconds: 7200,
                autoActEnabled: true,
                stagingFolderPath: "/Users/test/Documents/Sweep/Review",
                archiveFolderPath: "/Users/test/Documents/Sweep/Archive"
            ),
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try SweepJSON.encoder.encode(profile)
        let decoded = try SweepJSON.decoder.decode(ContextProfile.self, from: data)

        XCTAssertEqual(decoded.version, profile.version)
    }

    func testCodableRoundTripPreservesUserFacts() throws {
        let profile = ContextProfile(
            version: 1,
            userFacts: ["User works in finance", "Prefers clean desktop"],
            folderMap: [:],
            rules: [],
            preferences: .default,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try SweepJSON.encoder.encode(profile)
        let decoded = try SweepJSON.decoder.decode(ContextProfile.self, from: data)

        XCTAssertEqual(decoded.userFacts, profile.userFacts)
    }

    func testCodableRoundTripPreservesFolderMap() throws {
        let folderMap = [
            "invoices": "/Users/test/Documents/Finance/Invoices",
            "photos": "/Users/test/Pictures"
        ]
        let profile = ContextProfile(
            version: 1,
            userFacts: [],
            folderMap: folderMap,
            rules: [],
            preferences: .default,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try SweepJSON.encoder.encode(profile)
        let decoded = try SweepJSON.decoder.decode(ContextProfile.self, from: data)

        XCTAssertEqual(decoded.folderMap, profile.folderMap)
    }

    func testCodableRoundTripPreservesRules() throws {
        let rules = [
            Rule(id: "rule-a", description: "Rule A", examples: ["a.pdf"], createdBy: .claude, weight: 0.8),
            Rule(id: "rule-b", description: "Rule B", examples: [], createdBy: .user, weight: 1.2)
        ]
        let profile = ContextProfile(
            version: 1,
            userFacts: [],
            folderMap: [:],
            rules: rules,
            preferences: .default,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try SweepJSON.encoder.encode(profile)
        let decoded = try SweepJSON.decoder.decode(ContextProfile.self, from: data)

        XCTAssertEqual(decoded.rules.count, rules.count)
        XCTAssertEqual(decoded.rules, rules)
    }

    func testCodableRoundTripPreservesPreferences() throws {
        let prefs = SweepPreferences(
            scanIntervalSeconds: 1800,
            autoActEnabled: true,
            stagingFolderPath: "/custom/staging",
            archiveFolderPath: "/custom/archive"
        )
        let profile = ContextProfile(
            version: 1,
            userFacts: [],
            folderMap: [:],
            rules: [],
            preferences: prefs,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try SweepJSON.encoder.encode(profile)
        let decoded = try SweepJSON.decoder.decode(ContextProfile.self, from: data)

        XCTAssertEqual(decoded.preferences.scanIntervalSeconds, prefs.scanIntervalSeconds)
        XCTAssertEqual(decoded.preferences.autoActEnabled, prefs.autoActEnabled)
        XCTAssertEqual(decoded.preferences.stagingFolderPath, prefs.stagingFolderPath)
        XCTAssertEqual(decoded.preferences.archiveFolderPath, prefs.archiveFolderPath)
    }

    func testCodableRoundTripPreservesLastUpdated() throws {
        let lastUpdated = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = ContextProfile(
            version: 1,
            userFacts: [],
            folderMap: [:],
            rules: [],
            preferences: .default,
            lastUpdated: lastUpdated
        )

        let data = try SweepJSON.encoder.encode(profile)
        let decoded = try SweepJSON.decoder.decode(ContextProfile.self, from: data)

        // ISO 8601 round-trip has second-level precision
        XCTAssertEqual(decoded.lastUpdated.timeIntervalSince1970, lastUpdated.timeIntervalSince1970, accuracy: 1.0)
    }

    func testCodableRoundTripEquality() throws {
        let lastUpdated = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = ContextProfile(
            version: 1,
            userFacts: ["Fact A"],
            folderMap: ["archive": "/Users/test/Archive"],
            rules: [Rule(id: "r1", description: "Rule 1", examples: ["x.dmg"], createdBy: .seed, weight: 1.0)],
            preferences: SweepPreferences(
                scanIntervalSeconds: 3600,
                autoActEnabled: false,
                stagingFolderPath: "/staging",
                archiveFolderPath: "/archive"
            ),
            lastUpdated: lastUpdated
        )

        let data = try SweepJSON.encoder.encode(profile)
        let decoded = try SweepJSON.decoder.decode(ContextProfile.self, from: data)

        XCTAssertEqual(decoded, profile)
    }
}
