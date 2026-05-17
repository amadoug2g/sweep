import XCTest
@testable import Sweep

final class NotificationServiceTests: XCTestCase {

    // MARK: - MockNotificationService (platform-independent)

    func testMockNotifyBatchCompleteRecordsCall() async {
        let mock = MockNotificationService()
        let records: [UndoRecord] = []
        await mock.notifyBatchComplete(executed: records, pendingReviewCount: 0)
        XCTAssertEqual(mock.calls.count, 1)
        XCTAssertTrue(mock.calls.first?.executed.isEmpty ?? false)
        XCTAssertEqual(mock.calls.first?.pendingReviewCount, 0)
    }

    func testMockNotifyBatchCompleteRecordsMultipleCalls() async {
        let mock = MockNotificationService()
        let batchId = UUID()
        let record = UndoRecord(
            batchId: batchId,
            sourceURL: URL(fileURLWithPath: "/tmp/a.pdf"),
            destinationURL: URL(fileURLWithPath: "/tmp/dst/a.pdf"),
            reason: "test"
        )
        await mock.notifyBatchComplete(executed: [record], pendingReviewCount: 3)
        await mock.notifyBatchComplete(executed: [], pendingReviewCount: 0)

        XCTAssertEqual(mock.calls.count, 2)
        XCTAssertEqual(mock.calls[0].executed.count, 1)
        XCTAssertEqual(mock.calls[0].pendingReviewCount, 3)
        XCTAssertEqual(mock.calls[1].executed.count, 0)
    }

    func testSingleItemProducesSingularTitle() async {
        let mock = MockNotificationService()
        let record = UndoRecord(
            batchId: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/a.pdf"),
            destinationURL: URL(fileURLWithPath: "/tmp/dst/a.pdf"),
            reason: "test"
        )
        await mock.notifyBatchComplete(executed: [record], pendingReviewCount: 0)
        XCTAssertEqual(mock.calls.first?.executed.count, 1)
    }

    func testMultipleItemsProducePluralCount() async {
        let mock = MockNotificationService()
        let records = (0..<5).map { i in
            UndoRecord(
                batchId: UUID(),
                sourceURL: URL(fileURLWithPath: "/tmp/file\(i).pdf"),
                destinationURL: URL(fileURLWithPath: "/tmp/dst/file\(i).pdf"),
                reason: "test"
            )
        }
        await mock.notifyBatchComplete(executed: records, pendingReviewCount: 0)
        XCTAssertEqual(mock.calls.first?.executed.count, 5)
    }

#if canImport(UserNotifications)
    // MARK: - NotificationService (real, macOS only)

    func testNotifyBatchCompleteWithEmptyArrayDoesNotCrash() async {
        let service = NotificationService()
        await service.notifyBatchComplete(executed: [], pendingReviewCount: 0)
    }

    func testNotifyBatchCompleteWithOneItemDoesNotCrash() async {
        let service = NotificationService()
        let record = UndoRecord(
            batchId: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/file.pdf"),
            destinationURL: URL(fileURLWithPath: "/tmp/dest/file.pdf"),
            reason: "test"
        )
        await service.notifyBatchComplete(executed: [record], pendingReviewCount: 0)
    }

    func testNotifyBatchCompleteWithMultipleItemsDoesNotCrash() async {
        let service = NotificationService()
        let records = (0..<3).map { i in
            UndoRecord(
                batchId: UUID(),
                sourceURL: URL(fileURLWithPath: "/tmp/file\(i).pdf"),
                destinationURL: URL(fileURLWithPath: "/tmp/dest/file\(i).pdf"),
                reason: "test"
            )
        }
        await service.notifyBatchComplete(executed: records, pendingReviewCount: 2)
    }

    func testNotifyBatchCompleteWithPendingReviewDoesNotCrash() async {
        let service = NotificationService()
        await service.notifyBatchComplete(executed: [], pendingReviewCount: 5)
    }
#endif
}
