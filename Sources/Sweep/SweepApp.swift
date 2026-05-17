import SwiftUI

public struct SweepApp: App {
    @StateObject private var container = AppContainer.live

    public init() {}

    public var body: some Scene {
        MenuBarExtra("Sweep", systemImage: isScanning ? "arrow.clockwise" : "sparkles") {
            MenuBarRoot()
                .environmentObject(container)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(container)
        }
    }

    private var isScanning: Bool { container.isScanning }
}
