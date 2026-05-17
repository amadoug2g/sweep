import XCTest
@testable import Sweep

final class KeychainStoreTests: XCTestCase {

    // Each test gets a unique service name so Keychain entries never collide
    // across parallel runs or left-over state from prior runs.
    private var store: KeychainStore!
    private let testKey = "apiKey"

    override func setUp() {
        super.setUp()
        store = KeychainStore(service: "com.sweep.test.\(UUID().uuidString)")
    }

    override func tearDown() {
        // Clean up any key that may have been written during the test.
        store.delete(testKey)
        store = nil
        super.tearDown()
    }

    // MARK: - Save & Load round-trip

    func testSaveAndLoadRoundTrip() {
        let value = "sk-ant-test-value"
        XCTAssertTrue(store.save(key: testKey, value: value))
        XCTAssertEqual(store.load(key: testKey), value)
    }

    // MARK: - Load returns nil when key is absent

    func testLoadReturnsNilForMissingKey() {
        XCTAssertNil(store.load(key: "does.not.exist"))
    }

    // MARK: - Delete removes the value

    func testLoadReturnsNilAfterDelete() {
        store.save(key: testKey, value: "some-value")
        store.delete(testKey)
        XCTAssertNil(store.load(key: testKey))
    }

    // MARK: - Delete is idempotent (deleting a non-existent key does not crash)

    func testDeleteNonExistentKeyDoesNotCrash() {
        XCTAssertNoThrow(store.delete("never-saved"))
    }

    // MARK: - Update overwrites the previous value

    func testSaveOverwritesPreviousValue() {
        let original = "first-value"
        let updated  = "second-value"

        store.save(key: testKey, value: original)
        XCTAssertEqual(store.load(key: testKey), original)

        store.save(key: testKey, value: updated)
        XCTAssertEqual(store.load(key: testKey), updated)
    }

    // MARK: - Multiple distinct keys are stored independently

    func testMultipleKeysStoredIndependently() {
        let keyA = "keyA"
        let keyB = "keyB"
        defer {
            store.delete(keyA)
            store.delete(keyB)
        }

        store.save(key: keyA, value: "alpha")
        store.save(key: keyB, value: "beta")

        XCTAssertEqual(store.load(key: keyA), "alpha")
        XCTAssertEqual(store.load(key: keyB), "beta")
    }

    // MARK: - @discardableResult — save returns true on success

    func testSaveReturnsTrueOnSuccess() {
        let result = store.save(key: testKey, value: "value")
        XCTAssertTrue(result)
    }
}
