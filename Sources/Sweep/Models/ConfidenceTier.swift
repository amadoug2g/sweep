public enum ConfidenceTier: String, Codable, Equatable, Comparable, Sendable {
    case low, medium, high

    public static func < (lhs: ConfidenceTier, rhs: ConfidenceTier) -> Bool {
        let order: [ConfidenceTier] = [.low, .medium, .high]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
