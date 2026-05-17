@preconcurrency import Foundation

public struct FileItem: Codable, Hashable, Sendable {
    public let url: URL
    public let size: Int64
    public let createdAt: Date
    public let modifiedAt: Date
    public let mimeType: String?
    public let sha256Prefix: String?   // first 4KB SHA256, for dedup — nil is fine if not computed

    public init(url: URL, size: Int64, createdAt: Date, modifiedAt: Date, mimeType: String? = nil, sha256Prefix: String? = nil) {
        self.url = url
        self.size = size
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.mimeType = mimeType
        self.sha256Prefix = sha256Prefix
    }

    public var filename: String { url.lastPathComponent }
    public var fileExtension: String { url.pathExtension.lowercased() }
    public var ageInDays: Double { Date().timeIntervalSince(createdAt) / 86400 }
}
