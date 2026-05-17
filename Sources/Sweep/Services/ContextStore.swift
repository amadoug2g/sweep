@preconcurrency import Foundation

public final class ContextStore: ContextStoring {

    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!                                   // guaranteed by the system
            self.fileURL = appSupport
                .appendingPathComponent("Sweep", isDirectory: true)
                .appendingPathComponent("context.json")
        }
    }

    // MARK: - ContextStoring

    public func load() throws -> ContextProfile {
        try createDirectoryIfNeeded()

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            SweepLogger.storage.info("ContextStore.load: context.json not found — seeding defaults")
            let profile = ContextProfile.seed
            try save(profile)
            return profile
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let profile = try SweepJSON.decoder.decode(ContextProfile.self, from: data)
            SweepLogger.storage.debug("ContextStore.load: loaded profile version=\(profile.version)")
            return profile
        } catch {
            SweepLogger.storage.error("ContextStore.load: decode failed — \(error.localizedDescription)")
            throw error
        }
    }

    public func save(_ profile: ContextProfile) throws {
        try createDirectoryIfNeeded()

        let data: Data
        do {
            data = try SweepJSON.encoder.encode(profile)
        } catch {
            SweepLogger.storage.error("ContextStore.save: encode failed — \(error.localizedDescription)")
            throw error
        }

        // Atomic write: write to a sibling .tmp file, then replace.
        let tmpURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("context.tmp.json")

        do {
            try data.write(to: tmpURL, options: .atomic)
            // replaceItemAt atomically replaces on Apple platforms; fall back to
            // remove-then-move on Linux where replaceItemAt may not support a
            // missing destination.
            #if canImport(Darwin)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
            #else
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tmpURL, to: fileURL)
            #endif
            SweepLogger.storage.debug("ContextStore.save: wrote profile version=\(profile.version)")
        } catch {
            // Clean up tmp if it lingers.
            try? FileManager.default.removeItem(at: tmpURL)
            SweepLogger.storage.error("ContextStore.save: write failed — \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private helpers

    private func createDirectoryIfNeeded() throws {
        let dir = fileURL.deletingLastPathComponent()
        guard !FileManager.default.fileExists(atPath: dir.path) else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            SweepLogger.storage.info("ContextStore: created directory at \(dir.path)")
        } catch {
            SweepLogger.storage.error("ContextStore: failed to create directory — \(error.localizedDescription)")
            throw error
        }
    }
}
