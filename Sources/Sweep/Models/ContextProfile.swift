import Foundation

public struct SweepPreferences: Codable, Equatable, Sendable {
    public var scanIntervalSeconds: Int
    public var autoActEnabled: Bool
    public var stagingFolderPath: String
    public var archiveFolderPath: String

    public static let `default` = SweepPreferences(
        scanIntervalSeconds: 3600,
        autoActEnabled: false,
        stagingFolderPath: ("~/Documents/Sweep/Review" as NSString).expandingTildeInPath,
        archiveFolderPath: ("~/Documents/Sweep/Archive" as NSString).expandingTildeInPath
    )

    public init(scanIntervalSeconds: Int, autoActEnabled: Bool, stagingFolderPath: String, archiveFolderPath: String) {
        self.scanIntervalSeconds = scanIntervalSeconds
        self.autoActEnabled = autoActEnabled
        self.stagingFolderPath = stagingFolderPath
        self.archiveFolderPath = archiveFolderPath
    }
}

public struct ContextProfile: Codable, Equatable, Sendable {
    public var version: Int
    public var userFacts: [String]
    public var folderMap: [String: String]   // semantic tag → absolute path, e.g. "invoices" → "~/Documents/Finance/Invoices"
    public var rules: [Rule]
    public var preferences: SweepPreferences
    public var lastUpdated: Date

    public static let empty = ContextProfile(
        version: 1,
        userFacts: [],
        folderMap: [:],
        rules: [],
        preferences: .default,
        lastUpdated: Date()
    )

    public static let seed = ContextProfile(
        version: 1,
        userFacts: [],
        folderMap: [
            "review": ("~/Documents/Sweep/Review" as NSString).expandingTildeInPath,
            "archive": ("~/Documents/Sweep/Archive" as NSString).expandingTildeInPath
        ],
        rules: [
            Rule(id: "dmg-after-install", description: "DMG disk images can be archived after installation", examples: ["app-installer.dmg"], createdBy: .seed),
            Rule(id: "invoices-pdf", description: "PDFs with 'invoice' in the name belong in a Finance folder", examples: ["invoice_may.pdf", "Invoice_2026.pdf"], createdBy: .seed),
            Rule(id: "screenshots", description: "Screenshot files (PNG/JPG starting with 'Screenshot') can be reviewed", examples: ["Screenshot 2026-05-01.png"], createdBy: .seed)
        ],
        preferences: .default,
        lastUpdated: Date()
    )

    public init(version: Int, userFacts: [String], folderMap: [String: String], rules: [Rule], preferences: SweepPreferences, lastUpdated: Date) {
        self.version = version
        self.userFacts = userFacts
        self.folderMap = folderMap
        self.rules = rules
        self.preferences = preferences
        self.lastUpdated = lastUpdated
    }
}
