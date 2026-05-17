import Foundation

public struct PlannedItem: Codable, Equatable, Sendable {
    public let file: FileItem
    public let action: ProposedAction
    public let confidence: ConfidenceTier
    public let reason: String
    public let appliedRuleIds: [String]

    public init(file: FileItem, action: ProposedAction, confidence: ConfidenceTier, reason: String, appliedRuleIds: [String] = []) {
        self.file = file
        self.action = action
        self.confidence = confidence
        self.reason = reason
        self.appliedRuleIds = appliedRuleIds
    }
}
