import Foundation

#if canImport(os)
import os.log

public struct SweepLogCategory {
    private let logger: Logger
    init(subsystem: String, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
    }
    public func info(_ message: String) { logger.info("\(message, privacy: .public)") }
    public func debug(_ message: String) { logger.debug("\(message, privacy: .public)") }
    public func error(_ message: String) { logger.error("\(message, privacy: .public)") }
    public func warning(_ message: String) { logger.warning("\(message, privacy: .public)") }
}
#else
public struct SweepLogCategory {
    let category: String
    init(subsystem: String, category: String) { self.category = category }
    public func info(_ message: String) { print("[\(category)] \(message)") }
    public func debug(_ message: String) {}
    public func error(_ message: String) { print("[\(category)] ERROR: \(message)") }
    public func warning(_ message: String) { print("[\(category)] WARNING: \(message)") }
}
#endif

public enum SweepLogger {
    private static let subsystem = "com.sweep.app"

    public static let scanner  = SweepLogCategory(subsystem: subsystem, category: "scanner")
    public static let executor = SweepLogCategory(subsystem: subsystem, category: "executor")
    public static let claude   = SweepLogCategory(subsystem: subsystem, category: "claude")
    public static let storage  = SweepLogCategory(subsystem: subsystem, category: "storage")
    public static let ui       = SweepLogCategory(subsystem: subsystem, category: "ui")
    public static let trust    = SweepLogCategory(subsystem: subsystem, category: "trust")
    public static let undo     = SweepLogCategory(subsystem: subsystem, category: "undo")
}
