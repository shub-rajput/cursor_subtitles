import SwiftUI
import Speech
import AVFoundation

struct GeneralSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var showResetConfirmation = false
    @State private var dictationPermissionsGranted = SpeechManager.currentPermissionsGranted()

    private var behavior: BehaviorConfig { configManager.config.behavior }

    var body: some View {
        Form {
            AccessibilityBannerSection()
            Section {
                Toggle("Multi-line Pubble", isOn: multiLineBinding)

                if !behavior.multiLine {
                    Picker("Per Line Character Limit", selection: charLimitPickerBinding) {
                        ForEach([15, 20, 25, 30, 40, 50], id: \.self) { c in
                            Text("\(c)").tag(c)
                        }
                    }
                }
            }

            Section {
                Picker("Idle Timeout", selection: idleTimeoutBinding) {
                    ForEach([3.0, 5.0, 10.0, 20.0], id: \.self) { s in
                        Text("\(Int(s))s").tag(s)
                    }
                }

                Picker("Fade In", selection: fadeInBinding) {
                    ForEach([0.0, 0.1, 0.2, 0.3, 0.5], id: \.self) { s in
                        Text(s == 0 ? "Instant" : "\(s, specifier: "%.1f")s").tag(s)
                    }
                }

                Picker("Fade Out", selection: fadeOutBinding) {
                    ForEach([0.0, 0.2, 0.5, 0.8, 1.0], id: \.self) { s in
                        Text(s == 0 ? "Instant" : "\(s, specifier: "%.1f")s").tag(s)
                    }
                }
            }

            Section {
                HStack {
                    Text("Microphone & Speech Recognition")
                    Spacer()
                    if dictationPermissionsGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else if SpeechManager.permissionsPreviouslyDenied() {
                        Button("Open Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Grant Access") {
                            Task {
                                let granted = await SpeechManager.requestPermissions()
                                dictationPermissionsGranted = granted
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Section {
                Button("Reset Default Themes") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.red)
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
        }
        .formStyle(.grouped)
        .alert("Reset to Factory Defaults?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                configManager.resetToFactory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all built-in themes to their original values and clear any unsaved changes. Your custom themes will not be affected.")
        }
        .navigationTitle("Settings")
    }

    // MARK: - Bindings

    private var charLimitPickerBinding: Binding<Int> {
        Binding(
            get: { behavior.charLimit },
            set: { configManager.setBehaviorValue("charLimit", $0) }
        )
    }

    private var idleTimeoutBinding: Binding<Double> {
        Binding(
            get: { behavior.idleTimeout },
            set: { configManager.setBehaviorValue("idleTimeout", $0) }
        )
    }

    private var fadeInBinding: Binding<Double> {
        Binding(
            get: { behavior.fadeInDuration },
            set: { configManager.setBehaviorValue("fadeInDuration", $0) }
        )
    }

    private var fadeOutBinding: Binding<Double> {
        Binding(
            get: { behavior.fadeOutDuration },
            set: { configManager.setBehaviorValue("fadeOutDuration", $0) }
        )
    }

    private var multiLineBinding: Binding<Bool> {
        Binding(
            get: { behavior.multiLine },
            set: { configManager.setBehaviorValue("multiLine", $0) }
        )
    }

}
