import Foundation

public enum RuleOrigin: String, Codable, Equatable, Sendable {
    case seed   // shipped with app
    case claude // Claude proposed
    case user   // user wrote/confirmed
}

public struct Rule: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var description: String
    public var examples: [String]
    public var createdBy: RuleOrigin
    public var weight: Double   // 1.0 default; bumped on confirm, decayed on undo

    public init(id: String, description: String, examples: [String] = [], createdBy: RuleOrigin = .seed, weight: Double = 1.0) {
        self.id = id
        self.description = description
        self.examples = examples
        self.createdBy = createdBy
        self.weight = weight
    }
}
