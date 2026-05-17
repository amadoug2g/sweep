import Foundation
@testable import Sweep

/// A test double for `ClaudeClienting` that returns configurable results
/// and records every call made to it.
public final class MockClaudeClient: ClaudeClienting, @unchecked Sendable {

    // MARK: - Recorded calls

    /// Every (files, context) pair passed to `propose`.
    private(set) var calls: [(files: [FileItem], context: ContextProfile)] = []

    // MARK: - Configuration

    /// If set, `propose` throws this error instead of returning `stubbedResult`.
    var stubbedError: Error?

    /// The value returned by `propose` when `stubbedError` is nil.
    var stubbedResult: [PlannedItem] = []

    // MARK: - Init

    public init() {}

    // MARK: - ClaudeClienting

    public func propose(files: [FileItem], context: ContextProfile) async throws -> [PlannedItem] {
        calls.append((files: files, context: context))

        if let error = stubbedError {
            throw error
        }

        return stubbedResult
    }

    // MARK: - Convenience helpers

    /// The most recent call, or nil if `propose` has not been called.
    var lastCall: (files: [FileItem], context: ContextProfile)? { calls.last }

    /// Total number of times `propose` was called.
    var callCount: Int { calls.count }

    /// Reset recorded state and configuration back to defaults.
    func reset() {
        calls.removeAll()
        stubbedError = nil
        stubbedResult = []
    }
}
