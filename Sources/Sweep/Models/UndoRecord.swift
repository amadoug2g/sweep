import Foundation

public struct UndoRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let batchId: UUID            // groups actions from the same sweep run
    public let sourceURL: URL
    public let destinationURL: URL
    public let reason: String
    public let ruleIds: [String]
    public var undoneAt: Date?

    public var isUndone: Bool { undoneAt != nil }

    public init(id: UUID = UUID(), timestamp: Date = Date(), batchId: UUID, sourceURL: URL, destinationURL: URL, reason: String, ruleIds: [String] = []) {
        self.id = id
        self.timestamp = timestamp
        self.batchId = batchId
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.reason = reason
        self.ruleIds = ruleIds
        self.undoneAt = nil
    }
}
