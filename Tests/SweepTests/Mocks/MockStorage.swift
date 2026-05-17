import Foundation
@testable import Sweep

// MARK: - MockKeychainStore

public final class MockKeychainStore: KeychainStoring {

    private var store: [String: String] = [:]

    public init() {}

    @discardableResult
    public func save(key: String, value: String) -> Bool {
        store[key] = value
        return true
    }

    public func load(key: String) -> String? {
        store[key]
    }

    public func delete(key: String) {
        store.removeValue(forKey: key)
    }
}

// MARK: - MockContextStore

public final class MockContextStore: ContextStoring {

    private var stored: ContextProfile?

    /// When non-nil, `load()` and `save()` throw this error instead.
    public var stubbedError: Error?

    public init(initial: ContextProfile? = nil) {
        self.stored = initial
    }

    public func load() throws -> ContextProfile {
        if let error = stubbedError { throw error }
        return stored ?? .seed
    }

    public func save(_ profile: ContextProfile) throws {
        if let error = stubbedError { throw error }
        stored = profile
    }
}

// MARK: - MockTrustPhaseService

public final class MockTrustPhaseService: TrustPhasing {

    public var autoActEnabled: Bool
    public var isInTrustPeriod: Bool

    public private(set) var successCount: Int = 0
    public private(set) var undoCount: Int = 0

    public init(autoActEnabled: Bool = false, isInTrustPeriod: Bool = true) {
        self.autoActEnabled = autoActEnabled
        self.isInTrustPeriod = isInTrustPeriod
    }

    public func recordSuccessfulAction() {
        successCount += 1
    }

    public func recordUndoAction() {
        undoCount += 1
    }

    public func enableAutoAct() {
        autoActEnabled = true
    }

    public func disableAutoAct() {
        autoActEnabled = false
    }
}
