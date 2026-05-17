import Foundation
import UniformTypeIdentifiers

public final class DownloadsScanner: DownloadsScanning {

    private let downloadsURL: URL
    private let minimumAgeSeconds: TimeInterval

    // Extensions that indicate a download is still in progress.
    private static let inProgressExtensions: Set<String> = [
        "crdownload", "part", "download", "tmp"
    ]

    public init(
        downloadsURL: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
        minimumAgeSeconds: TimeInterval = 60
    ) {
        self.downloadsURL = downloadsURL
        self.minimumAgeSeconds = minimumAgeSeconds
    }

    public func scan() async throws -> ScanReport {
        let resourceKeys: [URLResourceKey] = [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .typeIdentifierKey,
            .isDirectoryKey
        ]

        let contents = try FileManager.default.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsPackageDescendants]
        )

        var items: [FileItem] = []
        var skippedCount = 0
        let now = Date()

        for url in contents {
            let name = url.lastPathComponent

            // Skip hidden files.
            if name.hasPrefix(".") {
                skippedCount += 1
                continue
            }

            // Skip in-progress extensions.
            let ext = url.pathExtension.lowercased()
            if Self.inProgressExtensions.contains(ext) {
                skippedCount += 1
                continue
            }

            let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

            // Skip directories.
            if resourceValues.isDirectory == true {
                skippedCount += 1
                continue
            }

            // Skip files modified too recently.
            let modifiedAt = resourceValues.contentModificationDate ?? now
            if now.timeIntervalSince(modifiedAt) < minimumAgeSeconds {
                skippedCount += 1
                continue
            }

            let size = Int64(resourceValues.fileSize ?? 0)
            let createdAt = resourceValues.creationDate ?? modifiedAt

            // Derive MIME type from UTI.
            var mimeType: String?
            if let typeIdentifier = resourceValues.typeIdentifier {
                if #available(macOS 11.0, *) {
                    if let utType = UTType(typeIdentifier) {
                        mimeType = utType.preferredMIMEType
                    }
                }
            }

            let item = FileItem(
                url: url,
                size: size,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                mimeType: mimeType,
                sha256Prefix: nil
            )
            items.append(item)
        }

        SweepLogger.scanner.info("Scan complete: \(items.count) items, \(skippedCount) skipped")
        return ScanReport(scannedAt: now, items: items, skippedCount: skippedCount)
    }
}
