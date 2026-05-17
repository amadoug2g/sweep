import Foundation
import os.log

public enum SweepLogger {
    private static let subsystem = "com.sweep.app"

    public static let scanner   = Logger(subsystem: subsystem, category: "scanner")
    public static let executor  = Logger(subsystem: subsystem, category: "executor")
    public static let claude    = Logger(subsystem: subsystem, category: "claude")
    public static let storage   = Logger(subsystem: subsystem, category: "storage")
    public static let ui        = Logger(subsystem: subsystem, category: "ui")
    public static let trust     = Logger(subsystem: subsystem, category: "trust")
    public static let undo      = Logger(subsystem: subsystem, category: "undo")
}
