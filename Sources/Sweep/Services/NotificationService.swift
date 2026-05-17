import Foundation
import UserNotifications

public final class NotificationService: Notifying, @unchecked Sendable {

    private static let categoryIdentifier = "SWEEP_BATCH"
    private static let undoActionIdentifier = "UNDO_BATCH"

    public init() {}

    public func notifyBatchComplete(executed: [UndoRecord], pendingReviewCount: Int) async {
        // Request permission if not already determined.
        await requestAuthorizationIfNeeded()

        // Register notification category with Undo action.
        registerCategory()

        // Build notification content.
        let content = UNMutableNotificationContent()
        let count = executed.count
        content.title = "Sweep filed \(count) item\(count == 1 ? "" : "s")"
        if pendingReviewCount > 0 {
            content.body = "\(pendingReviewCount) waiting in Review"
        }
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            SweepLogger.ui.info("Notification scheduled: \(count) items filed, \(pendingReviewCount) pending review")
        } catch {
            SweepLogger.ui.error("Failed to schedule notification: \(error)")
        }
    }

    // MARK: - Helpers

    private func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            SweepLogger.ui.info("Notification permission granted: \(granted)")
        } catch {
            SweepLogger.ui.error("Notification permission request failed: \(error)")
        }
    }

    private func registerCategory() {
        let undoAction = UNNotificationAction(
            identifier: Self.undoActionIdentifier,
            title: "Undo",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [undoAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
