#if canImport(AppKit)
import SwiftUI
import AppKit

struct MenuBarRoot: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader

            Divider()

            sweepButton

            Divider()

            if !container.recentActions.isEmpty {
                recentActivitySection
                Divider()
            }

            if !container.pendingReviewItems.isEmpty {
                reviewLink
                Divider()
            }

            footerLinks
        }
        .frame(width: 280)
        .onAppear { container.refreshRecentActions() }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        Group {
            if container.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning Downloads…")
                        .font(.callout)
                }
            } else if let errorMessage = container.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let lastScanDate = container.lastScanDate {
                Text("\(container.downloadsCount) file\(container.downloadsCount == 1 ? "" : "s") · last scan \(relativeTime(from: lastScanDate))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready to sweep")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Sweep Button

    private var sweepButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                Task { await container.sweep() }
            } label: {
                Text("Sweep Now")
                    .font(.body.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
            .disabled(container.isScanning || !container.hasAPIKey)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !container.hasAPIKey {
                Text("Add API key in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(container.recentActions.prefix(5)) { record in
                recentActionRow(record)
            }
        }
    }

    private func recentActionRow(_ record: UndoRecord) -> some View {
        HStack(spacing: 6) {
            Text(record.sourceURL.lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .strikethrough(record.isUndone)
                .foregroundStyle(record.isUndone ? .secondary : .primary)

            Spacer()

            Text(record.reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            if !record.isUndone {
                Button("Undo") {
                    container.undo(record: record)
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Review Link

    private var reviewLink: some View {
        Button {
            let path = ("~/Documents/Sweep/Review" as NSString).expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } label: {
            HStack {
                Text("Review (\(container.pendingReviewItems.count))")
                    .font(.callout)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Footer Links

    private var footerLinks: some View {
        HStack {
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func relativeTime(from date: Date) -> String {
        let elapsed = Date().timeIntervalSince(date)
        switch elapsed {
        case ..<60:
            return "just now"
        case 60..<3600:
            let minutes = Int(elapsed / 60)
            return "\(minutes)m ago"
        case 3600..<86400:
            let hours = Int(elapsed / 3600)
            return "\(hours)h ago"
        default:
            let days = Int(elapsed / 86400)
            return "\(days)d ago"
        }
    }
}
#endif
