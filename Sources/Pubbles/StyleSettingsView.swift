import SwiftUI
import AppKit

struct StyleSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared

    private var style: StyleConfig { configManager.config.style }

    var body: some View {
        VStack(spacing: 0) {
            previewArea
            Divider()
            settingsForm
        }
        .navigationTitle("Style")
    }

    // MARK: - Preview Area (sticky, non-scrolling)

    private var previewArea: some View {
        VStack(spacing: 12) {
            // Theme row
            HStack {
                Text(currentThemeName)
                    .font(.subheadline)
                Spacer()
                Button("Edit Config File") {
                    NSWorkspace.shared.open(
                        FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent(".config/pubbles/config.json")
                    )
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                Button("Reset") {
                    configManager.resetStyleOverrides()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Theme carousel with arrows
            HStack {
                Button {
                    configManager.cycleTheme(forward: false)
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
                PillPreview(style: style)
                Spacer()

                Button {
                    configManager.cycleTheme(forward: true)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Page indicator dots (placeholder)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == 0 ? Color.secondary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(20)
        .background(.quaternary.opacity(0.5))
        .clipped()
    }

    private var currentThemeName: String {
        guard let themeFile = configManager.config.theme else { return "Default" }
        let themes = configManager.availableThemes()
        return themes.first(where: { $0.filename == themeFile })?.name ?? themeFile
    }

    // MARK: - Settings Form

    private var settingsForm: some View {
        Form {
            appearanceSection
            borderSection
            shadowSection
            drawingSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var hasGradient: Bool {
        (style.backgroundGradient?.count ?? 0) >= 2
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            if !style.glassEffect {
                HStack {
                    Text("Bubble Background")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { hasGradient ? 1 : 0 },
                        set: { newValue in
                            if newValue == 1 {
                                let base = style.backgroundColor
                                configManager.setStyleValue("backgroundGradient", [base, base])
                            } else {
                                configManager.removeStyleValue("backgroundGradient")
                            }
                        }
                    )) {
                        Text("Solid").tag(0)
                        Text("Gradient").tag(1)
                    }
                    .labelsHidden()
                    .fixedSize()

                    if !hasGradient {
                        ColorPicker("", selection: bgColorWithOpacityBinding, supportsOpacity: true)
                            .labelsHidden()
                    }
                }

                if hasGradient {
                    HStack {
                        Text("Gradient")
                        Spacer()
                        GradientPicker(
                            colors: Binding(
                                get: { style.backgroundGradient ?? [] },
                                set: { configManager.setStyleValue("backgroundGradient", $0) }
                            )
                        )
                        .frame(width: 200, height: 22)
                    }
                }
            }

            ColorPicker("Text Color", selection: textColorBinding, supportsOpacity: false)

            Picker("Font Size", selection: fontSizePickerBinding) {
                ForEach([10, 12, 14, 16, 18, 20, 24], id: \.self) { size in
                    Text("\(size)pt").tag(CGFloat(size))
                }
            }

            Picker("Font Family", selection: fontFamilyBinding) {
                Text("System").tag("system")
                Text("SF Mono").tag("SF Mono")
                Text("Menlo").tag("Menlo")
                Text("Helvetica Neue").tag("Helvetica Neue")
                Text("Avenir Next").tag("Avenir Next")
            }

            Picker("Scale", selection: scalePickerBinding) {
                Text("0.8x").tag(CGFloat(0.8))
                Text("1x").tag(CGFloat(1.0))
                Text("1.3x").tag(CGFloat(1.3))
                Text("1.6x").tag(CGFloat(1.6))
                Text("2x").tag(CGFloat(2.0))
            }
        }
    }

    // MARK: - Border

    private var borderSection: some View {
        Section("Border") {
            ColorPicker("Border Color", selection: borderColorBinding, supportsOpacity: false)

            Picker("Border Width", selection: borderWidthPickerBinding) {
                ForEach([0, 1, 2, 3, 4], id: \.self) { w in
                    Text("\(w)px").tag(CGFloat(w))
                }
            }

            Toggle("Sharp Corner", isOn: pointerCornerBinding)

            Picker("Corner Radius", selection: cornerRadiusPickerBinding) {
                ForEach([4, 8, 12, 16, 20, 24], id: \.self) { r in
                    Text("\(r)px").tag(CGFloat(r))
                }
            }
        }
    }

    // MARK: - Shadow

    private var shadowSection: some View {
        Section("Shadow") {
            ColorPicker("Shadow Color", selection: shadowColorBinding, supportsOpacity: false)

            HStack {
                Text("Opacity")
                Slider(value: shadowOpacityBinding, in: 0...1, step: 0.05)
                Text("\(Int(style.shadowOpacity * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("X Offset")
                Slider(value: shadowXBinding, in: -10...10, step: 1)
                Text("\(Int(style.shadowX))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }

            HStack {
                Text("Y Offset")
                Slider(value: shadowYBinding, in: -10...10, step: 1)
                Text("\(Int(style.shadowY))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }

            HStack {
                Text("Blur Radius")
                Slider(value: shadowRadiusBinding, in: 0...20, step: 1)
                Text("\(Int(style.shadowRadius))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    // MARK: - Drawing

    private var drawingSection: some View {
        Section("Drawing") {
            ColorPicker("Line Color", selection: drawingColorBinding, supportsOpacity: false)

            Picker("Line Width", selection: drawingLineWidthPickerBinding) {
                ForEach([1, 2, 3, 4, 5], id: \.self) { w in
                    Text("\(w)px").tag(CGFloat(w))
                }
            }
        }
    }

    // MARK: - Bindings

    private var bgColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.backgroundColor) ?? .blue },
            set: { configManager.setColor($0.toHex()) }
        )
    }

    private var bgColorWithOpacityBinding: Binding<Color> {
        Binding(
            get: {
                (Color(hex: style.backgroundColor) ?? .blue)
                    .opacity(style.backgroundOpacity)
            },
            set: { newColor in
                let nsColor = NSColor(newColor)
                let opacity = Double(nsColor.alphaComponent)
                let opaque = nsColor.withAlphaComponent(1.0)
                configManager.setColor(Color(opaque).toHex())
                configManager.setStyleValue("backgroundOpacity", opacity)
            }
        )
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.textColor) ?? .white },
            set: { configManager.setStyleValue("textColor", $0.toHex()) }
        )
    }

    private var borderColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.borderColor) ?? .white },
            set: { configManager.setStyleValue("borderColor", $0.toHex()) }
        )
    }

    private var shadowColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.shadowColor) ?? .black },
            set: { configManager.setStyleValue("shadowColor", $0.toHex()) }
        )
    }

    private var drawingColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.drawingLineColor) ?? .red },
            set: { configManager.setStyleValue("drawingLineColor", $0.toHex()) }
        )
    }

    private var fontSizePickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.fontSize },
            set: { configManager.setStyleValue("fontSize", $0) }
        )
    }

    private var fontFamilyBinding: Binding<String> {
        Binding(
            get: { style.fontFamily },
            set: { configManager.setStyleValue("fontFamily", $0) }
        )
    }

    private var scalePickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.pillScale },
            set: { configManager.setStyleValue("pillScale", $0) }
        )
    }

    private var borderWidthPickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.borderWidth },
            set: { configManager.setStyleValue("borderWidth", $0) }
        )
    }

    private var pointerCornerBinding: Binding<Bool> {
        Binding(
            get: { style.pointerCorner },
            set: { configManager.setStyleValue("pointerCorner", $0) }
        )
    }

    private var cornerRadiusPickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.cornerRadius },
            set: { configManager.setStyleValue("cornerRadius", $0) }
        )
    }

    private var shadowOpacityBinding: Binding<Double> {
        Binding(
            get: { style.shadowOpacity },
            set: { configManager.setStyleValue("shadowOpacity", $0) }
        )
    }

    private var shadowXBinding: Binding<Double> {
        Binding(
            get: { Double(style.shadowX) },
            set: { configManager.setStyleValue("shadowX", $0) }
        )
    }

    private var shadowYBinding: Binding<Double> {
        Binding(
            get: { Double(style.shadowY) },
            set: { configManager.setStyleValue("shadowY", $0) }
        )
    }

    private var shadowRadiusBinding: Binding<Double> {
        Binding(
            get: { Double(style.shadowRadius) },
            set: { configManager.setStyleValue("shadowRadius", $0) }
        )
    }

    private var drawingLineWidthPickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.drawingLineWidth },
            set: { configManager.setStyleValue("drawingLineWidth", $0) }
        )
    }
}
