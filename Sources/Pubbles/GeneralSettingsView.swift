import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var showResetConfirmation = false

    private var behavior: BehaviorConfig { configManager.config.behavior }

    var body: some View {
        Form {
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
            }
            Section {
                Button("Reset to Factory Defaults") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.red)
            }
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

    private var multiLineBinding: Binding<Bool> {
        Binding(
            get: { behavior.multiLine },
            set: { configManager.setBehaviorValue("multiLine", $0) }
        )
    }

}
