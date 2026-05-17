import Foundation

public final class ActionExecutor: ActionExecuting {

    private let fileManager: FileManager
    private let undoLog: UndoLogging

    public init(fileManager: FileManager = .default, undoLog: UndoLogging) {
        self.fileManager = fileManager
        self.undoLog = undoLog
    }

    public func execute(_ items: [PlannedItem], batchId: UUID) async throws -> [UndoRecord] {
        var records: [UndoRecord] = []

        for item in items {
            guard let destinationDir = resolveDestinationDirectory(for: item.action) else {
                // .keep — nothing to do.
                SweepLogger.executor.debug("Keeping \(item.file.filename) in place")
                continue
            }

            // Create destination directory if needed.
            do {
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            } catch {
                SweepLogger.executor.error("Failed to create directory \(destinationDir.path): \(error)")
                continue
            }

            // Resolve final destination URL, handling filename collisions.
            let finalDestination = resolveCollision(
                for: item.file.url.lastPathComponent,
                in: destinationDir
            )

            // Build the undo record.
            let record = UndoRecord(
                batchId: batchId,
                sourceURL: item.file.url,
                destinationURL: finalDestination,
                reason: item.action.reason,
                ruleIds: item.appliedRuleIds
            )

            // Write undo record BEFORE moving the file so it's never lost.
            do {
                try undoLog.record(record)
            } catch {
                SweepLogger.executor.error("Failed to write undo record for \(item.file.filename): \(error) — skipping move")
                continue
            }

            // Move the file.
            do {
                try fileManager.moveItem(at: item.file.url, to: finalDestination)
                SweepLogger.executor.info("Moved \(item.file.filename) → \(finalDestination.path)")
                records.append(record)
            } catch {
                SweepLogger.executor.error("Failed to move \(item.file.filename): \(error)")
                // Continue with remaining items; don't abort the whole batch.
            }
        }

        return records
    }

    // MARK: - Helpers

    private func resolveDestinationDirectory(for action: ProposedAction) -> URL? {
        switch action {
        case .keep:
            return nil

        case .move(let destination, _):
            // destination is the full target URL; return its directory.
            return destination.deletingLastPathComponent()

        case .archive:
            let monthFolder = currentYearMonthString()
            let path = ("~/Documents/Sweep/Archive/" + monthFolder as NSString).expandingTildeInPath
            return URL(fileURLWithPath: path)

        case .reviewLater:
            let path = ("~/Documents/Sweep/Review" as NSString).expandingTildeInPath
            return URL(fileURLWithPath: path)
        }
    }

    /// Returns the final destination URL for a file, appending ` (N)` before the extension
    /// when the destination already exists.
    private func resolveCollision(for filename: String, in directory: URL) -> URL {
        let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let ext  = (filename as NSString).pathExtension

        var candidate = directory.appendingPathComponent(filename)
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }

        return candidate
    }

    private func currentYearMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
