import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared

    private var style: StyleConfig { configManager.config.style }
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

                Picker("Max Width", selection: maxWidthPickerBinding) {
                    ForEach([150, 200, 250, 300, 400, 500, 600], id: \.self) { w in
                        Text("\(w)px").tag(CGFloat(w))
                    }
                }
            }

            Section {
                HStack {
                    Text("Idle Timeout")
                        .frame(width: 72, alignment: .leading)
                    Slider(value: idleTimeoutBinding, in: 1...30)
                    Text("\(Int(behavior.idleTimeout))s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    // MARK: - Bindings

    private var maxWidthPickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.maxWidth },
            set: { configManager.setStyleValue("maxWidth", $0) }
        )
    }

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
