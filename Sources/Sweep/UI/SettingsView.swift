#if canImport(AppKit)
import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var container: AppContainer
    @State private var apiKeyInput: String = ""
    @State private var showKeyField: Bool = false
    @State private var isTestingKey: Bool = false
    @State private var testResult: String? = nil

    var body: some View {
        Form {
            // Section: API Key
            Section("Claude API Key") {
                if container.hasAPIKey && !showKeyField {
                    HStack {
                        Label("Key saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Replace") { showKeyField = true }
                    }
                } else {
                    SecureField("sk-ant-...", text: $apiKeyInput)
                    HStack {
                        Button("Save") { saveKey() }
                            .disabled(apiKeyInput.isEmpty)
                        if isTestingKey {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        if let result = testResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.hasPrefix("✓") ? .green : .red)
                        }
                    }
                }
            }

            // Section: Behaviour
            Section("Behaviour") {
                HStack {
                    Text("Auto-act (high confidence)")
                    Spacer()
                    if container.trust.isInTrustPeriod {
                        Text("Available after trust period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { container.trust.autoActEnabled },
                            set: { enabled in
                                if enabled {
                                    container.trust.enableAutoAct()
                                } else {
                                    container.trust.disableAutoAct()
                                }
                            }
                        ))
                    }
                }
                Text("During the first 7 days, all actions go to Review for your approval.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Section: Storage
            Section("Storage") {
                Button("Open context.json") {
                    if let store = container.contextStore as? ContextStore {
                        NSWorkspace.shared.open(store.fileURL)
                    }
                }
                Button("Reset learning") {
                    // clear context, reset trust phase — future PR
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
        .onAppear {
            // LSUIElement apps don't activate automatically when a window opens,
            // so the Settings window can appear behind other apps. Force-activate
            // to bring it to the front.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Helpers

    private func saveKey() {
        container.saveAPIKey(apiKeyInput)
        showKeyField = false
        testResult = nil
        isTestingKey = false
    }
}
#endif
