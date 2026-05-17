@preconcurrency import Foundation

public final class TrustPhaseService: TrustPhasing {

    // MARK: - UserDefaults keys

    private enum Keys {
        static let installDate    = "sweep.installDate"
        static let autoActEnabled = "sweep.autoActEnabled"
        static let successCount   = "sweep.successCount"
        static let undoCount      = "sweep.undoCount"
    }

    private let trustPeriodDays: Double = 7

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ensureInstallDate()
    }

    // MARK: - TrustPhasing

    public var autoActEnabled: Bool {
        defaults.bool(forKey: Keys.autoActEnabled)
    }

    public var isInTrustPeriod: Bool {
        guard let installDate = defaults.object(forKey: Keys.installDate) as? Date else {
            // Should never happen after init, but be safe.
            SweepLogger.trust.error("TrustPhaseService.isInTrustPeriod: installDate missing")
            return true
        }
        let elapsed = Date().timeIntervalSince(installDate)
        let result = elapsed < trustPeriodDays * 86_400
        SweepLogger.trust.debug("TrustPhaseService.isInTrustPeriod: elapsed=\(elapsed) result=\(result)")
        return result
    }

    public func recordSuccessfulAction() {
        let current = defaults.integer(forKey: Keys.successCount)
        defaults.set(current + 1, forKey: Keys.successCount)
        SweepLogger.trust.debug("TrustPhaseService: successCount now \(current + 1)")
    }

    public func recordUndoAction() {
        let current = defaults.integer(forKey: Keys.undoCount)
        defaults.set(current + 1, forKey: Keys.undoCount)
        SweepLogger.trust.debug("TrustPhaseService: undoCount now \(current + 1)")
    }

    public func enableAutoAct() {
        defaults.set(true, forKey: Keys.autoActEnabled)
        SweepLogger.trust.info("TrustPhaseService: autoAct enabled")
    }

    public func disableAutoAct() {
        defaults.set(false, forKey: Keys.autoActEnabled)
        SweepLogger.trust.info("TrustPhaseService: autoAct disabled")
    }

    // MARK: - Private helpers

    private func ensureInstallDate() {
        guard defaults.object(forKey: Keys.installDate) == nil else { return }
        let now = Date()
        defaults.set(now, forKey: Keys.installDate)
        SweepLogger.trust.info("TrustPhaseService: recorded install date \(now)")
    }
}
