@preconcurrency import Foundation

public enum ProposedAction: Equatable, Sendable {
    case move(destination: URL, reason: String)
    case archive(reason: String)       // → ~/Documents/Sweep/Archive/yyyy-mm/
    case reviewLater(reason: String)   // → ~/Documents/Sweep/Review/
    case keep(reason: String)          // leave in Downloads

    public var reason: String {
        switch self {
        case .move(_, let r), .archive(let r), .reviewLater(let r), .keep(let r): return r
        }
    }

    public var isAutoActable: Bool {
        switch self {
        case .move: return true
        case .archive: return true
        case .reviewLater: return false
        case .keep: return false
        }
    }
}

// Custom Codable since associated values differ
extension ProposedAction: Codable {
    private enum CodingKeys: String, CodingKey { case type, destination, reason }
    private enum ActionType: String, Codable { case move, archive, reviewLater, keep }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .move(let dest, let reason):
            try c.encode(ActionType.move, forKey: .type)
            try c.encode(dest.path, forKey: .destination)
            try c.encode(reason, forKey: .reason)
        case .archive(let reason):
            try c.encode(ActionType.archive, forKey: .type)
            try c.encode(reason, forKey: .reason)
        case .reviewLater(let reason):
            try c.encode(ActionType.reviewLater, forKey: .type)
            try c.encode(reason, forKey: .reason)
        case .keep(let reason):
            try c.encode(ActionType.keep, forKey: .type)
            try c.encode(reason, forKey: .reason)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(ActionType.self, forKey: .type)
        let reason = try c.decode(String.self, forKey: .reason)
        switch type {
        case .move:
            let destPath = try c.decode(String.self, forKey: .destination)
            self = .move(destination: URL(fileURLWithPath: destPath), reason: reason)
        case .archive:
            self = .archive(reason: reason)
        case .reviewLater:
            self = .reviewLater(reason: reason)
        case .keep:
            self = .keep(reason: reason)
        }
    }
}
