import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared

    private var style: StyleConfig { configManager.config.style }
    private var behavior: BehaviorConfig { configManager.config.behavior }

    var body: some View {
        Form {
            Section("Text") {
                Picker("Max Width", selection: maxWidthPickerBinding) {
                    ForEach([150, 200, 250, 300, 400, 500, 600], id: \.self) { w in
                        Text("\(w)px").tag(CGFloat(w))
                    }
                }

                Picker("Char Limit", selection: charLimitPickerBinding) {
                    ForEach([15, 20, 25, 30, 40, 50], id: \.self) { c in
                        Text("\(c)").tag(c)
                    }
                }
            }

            Section("Behavior") {
                HStack {
                    Text("Idle Timeout")
                    Slider(value: idleTimeoutBinding, in: 1...30, step: 1)
                    Text("\(Int(behavior.idleTimeout))s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
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
}
