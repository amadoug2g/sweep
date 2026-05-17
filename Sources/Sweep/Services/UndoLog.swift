import Foundation

public final class UndoLog: UndoLogging, @unchecked Sendable {

    public let fileURL: URL

    // Serial queue to protect JSONL file access.
    private let queue = DispatchQueue(label: "com.sweep.undolog", qos: .utility)

    public init(fileURL: URL? = nil) {
        if let provided = fileURL {
            self.fileURL = provided
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
            let sweepDir = appSupport.appendingPathComponent("Sweep", isDirectory: true)
            // Best-effort directory creation; tolerate pre-existing directory.
            try? FileManager.default.createDirectory(at: sweepDir, withIntermediateDirectories: true)
            self.fileURL = sweepDir.appendingPathComponent("undo.jsonl")
        }
    }

    // MARK: - UndoLogging

    public func record(_ record: UndoRecord) throws {
        let line = try encodeLine(record)
        try queue.sync {
            try appendLine(line)
        }
        SweepLogger.undo.info("Recorded undo for \(record.sourceURL.lastPathComponent) id=\(record.id)")
    }

    @discardableResult
    public func undo(id: UUID) throws -> UndoRecord {
        let result: Result<UndoRecord, Error> = queue.sync {
            Result {
                var all = try readAll()
                guard let idx = all.firstIndex(where: { $0.id == id }) else {
                    throw UndoError.recordNotFound(id)
                }
                var target = all[idx]

                // Verify the file is actually at the destination before trying to move.
                guard FileManager.default.fileExists(atPath: target.destinationURL.path) else {
                    throw UndoError.fileNotAtDestination(target.destinationURL)
                }

                try FileManager.default.moveItem(at: target.destinationURL, to: target.sourceURL)
                target.undoneAt = Date()
                all[idx] = target
                try writeAll(all)
                SweepLogger.undo.info("Undone record id=\(id)")
                return target
            }
        }
        return try result.get()
    }

    public func undoLastBatch(batchId: UUID) throws -> [UndoRecord] {
        let result: Result<[UndoRecord], Error> = queue.sync {
            Result {
                var all = try readAll()
                // Collect non-undone records matching batchId, most recent first.
                let targets = all
                    .filter { $0.batchId == batchId && !$0.isUndone }
                    .sorted { $0.timestamp > $1.timestamp }

                var undone: [UndoRecord] = []
                let now = Date()

                for target in targets {
                    guard FileManager.default.fileExists(atPath: target.destinationURL.path) else {
                        SweepLogger.undo.warning("File not at destination, skipping undo for \(target.id)")
                        continue
                    }
                    do {
                        try FileManager.default.moveItem(at: target.destinationURL, to: target.sourceURL)
                        if let idx = all.firstIndex(where: { $0.id == target.id }) {
                            all[idx].undoneAt = now
                        }
                        undone.append(target)
                    } catch {
                        SweepLogger.undo.error("Failed to undo \(target.id): \(error)")
                    }
                }

                try writeAll(all)
                SweepLogger.undo.info("Undid \(undone.count) records for batchId=\(batchId)")
                return undone
            }
        }
        return try result.get()
    }

    public func recentRecords(limit: Int) -> [UndoRecord] {
        let records = (try? queue.sync { try readAll() }) ?? []
        return Array(records.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    public func purgeOlderThan(days: Int) throws {
        let result: Result<Void, Error> = queue.sync {
            Result {
                let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
                let hardCutoff = Date().addingTimeInterval(-90 * 86_400)
                var all = try readAll()
                all = all.filter { record in
                    // Keep if within the requested age window and not yet undone.
                    let isOldAndUndone = record.timestamp < cutoff && record.undoneAt != nil
                    let isVeryOld = record.timestamp < hardCutoff
                    return !isOldAndUndone && !isVeryOld
                }
                try writeAll(all)
                SweepLogger.undo.info("Purged records older than \(days) days")
            }
        }
        try result.get()
    }

    // MARK: - JSONL I/O

    private func readAll() throws -> [UndoRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        return try lines.map { lineData in
            try SweepJSON.decoder.decode(UndoRecord.self, from: Data(lineData))
        }
    }

    private func writeAll(_ records: [UndoRecord]) throws {
        let lines = try records.map { try encodeLine($0) }
        let content = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func appendLine(_ line: String) throws {
        let lineWithNewline = line + "\n"
        let data = Data(lineWithNewline.utf8)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private func encodeLine(_ record: UndoRecord) throws -> String {
        // Use compact (non-pretty-printed) encoding for JSONL — one object per line.
        let compactEncoder = JSONEncoder()
        compactEncoder.dateEncodingStrategy = .iso8601
        let data = try compactEncoder.encode(record)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Errors

public enum UndoError: Error, LocalizedError {
    case recordNotFound(UUID)
    case fileNotAtDestination(URL)

    public var errorDescription: String? {
        switch self {
        case .recordNotFound(let id):
            return "No undo record found with id \(id)"
        case .fileNotAtDestination(let url):
            return "File no longer exists at destination: \(url.path)"
        }
    }
}
