import Foundation

public struct ScanReport: Sendable {
    public let scannedAt: Date
    public let items: [FileItem]
    public let skippedCount: Int

    public init(scannedAt: Date = Date(), items: [FileItem], skippedCount: Int = 0) {
        self.scannedAt = scannedAt
        self.items = items
        self.skippedCount = skippedCount
    }
}
