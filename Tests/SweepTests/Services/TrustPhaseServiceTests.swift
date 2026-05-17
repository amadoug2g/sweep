import XCTest
@testable import Sweep

final class TrustPhaseServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var service: TrustPhaseService!

    override func setUp() {
        super.setUp()
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        service = TrustPhaseService(defaults: defaults)
    }

    override func tearDown() {
        // Wipe the entire suite so nothing leaks between tests.
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        service = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Fresh install sets installDate

    func testFreshInstallSetsInstallDate() {
        // The service was just initialised in setUp — installDate must now exist.
        let stored = defaults.object(forKey: "sweep.installDate")
        XCTAssertNotNil(stored, "installDate must be written on first init")
        XCTAssertTrue(stored is Date)
    }

    // MARK: - installDate is not overwritten on subsequent inits

    func testInstallDateIsNotOverwrittenOnReInit() {
        guard let first = defaults.object(forKey: "sweep.installDate") as? Date else {
            return XCTFail("installDate should be set by setUp")
        }

        // Create a second instance with the same defaults — date must be unchanged.
        let second = TrustPhaseService(defaults: defaults)
        _ = second.isInTrustPeriod   // access to ensure no side-effect

        guard let again = defaults.object(forKey: "sweep.installDate") as? Date else {
            return XCTFail("installDate disappeared after second init")
        }
        XCTAssertEqual(first, again)
    }

    // MARK: - isInTrustPeriod is true on day 0

    func testIsInTrustPeriodTrueOnDayZero() {
        // Install date was just set — we are well within the 7-day window.
        XCTAssertTrue(service.isInTrustPeriod)
    }

    // MARK: - isInTrustPeriod is false after 7 days

    func testIsInTrustPeriodFalseAfterSevenDays() {
        // Backdate the install date by 8 days.
        let eightDaysAgo = Date().addingTimeInterval(-8 * 86_400)
        defaults.set(eightDaysAgo, forKey: "sweep.installDate")

        XCTAssertFalse(service.isInTrustPeriod)
    }

    // MARK: - autoActEnabled is false by default

    func testAutoActEnabledIsFalseByDefault() {
        XCTAssertFalse(service.autoActEnabled)
    }

    // MARK: - enableAutoAct persists to UserDefaults

    func testEnableAutoActPersists() {
        service.enableAutoAct()
        XCTAssertTrue(service.autoActEnabled)
        XCTAssertTrue(defaults.bool(forKey: "sweep.autoActEnabled"))
    }

    // MARK: - disableAutoAct persists to UserDefaults

    func testDisableAutoActPersists() {
        service.enableAutoAct()
        service.disableAutoAct()
        XCTAssertFalse(service.autoActEnabled)
        XCTAssertFalse(defaults.bool(forKey: "sweep.autoActEnabled"))
    }

    // MARK: - recordSuccessfulAction increments successCount

    func testRecordSuccessfulActionIncrementsCount() {
        service.recordSuccessfulAction()
        service.recordSuccessfulAction()
        XCTAssertEqual(defaults.integer(forKey: "sweep.successCount"), 2)
    }

    // MARK: - recordUndoAction increments undoCount

    func testRecordUndoActionIncrementsCount() {
        service.recordUndoAction()
        XCTAssertEqual(defaults.integer(forKey: "sweep.undoCount"), 1)
    }

    // MARK: - success and undo counts are independent

    func testSuccessAndUndoCountsAreIndependent() {
        service.recordSuccessfulAction()
        service.recordSuccessfulAction()
        service.recordSuccessfulAction()
        service.recordUndoAction()

        XCTAssertEqual(defaults.integer(forKey: "sweep.successCount"), 3)
        XCTAssertEqual(defaults.integer(forKey: "sweep.undoCount"), 1)
    }

    // MARK: - autoAct state survives re-init from same defaults

    func testAutoActStateSurvivesReInit() {
        service.enableAutoAct()

        let second = TrustPhaseService(defaults: defaults)
        XCTAssertTrue(second.autoActEnabled)
    }
}
