import SwiftUI

public struct SweepApp: App {
    public init() {}

    public var body: some Scene {
        MenuBarExtra("Sweep", systemImage: "arrow.up.and.down.and.sparkles") {
            MenuBarRoot()
        }
    }
}

struct MenuBarRoot: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Sweep")
                .font(.headline)
            Text("Coming soon")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding()
    }
}
