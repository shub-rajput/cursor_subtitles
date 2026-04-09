import SwiftUI
import AppKit

private let pillPreviewTexts = [
    "Get Pubblin'",
    "Looking good today",
    "Hmm...ship it",
    "That's a vibe",
    "Welp ¯\\_(ツ)_/¯",
    "Ooh, fancy!",
    "Chef's kiss",
    "Dip them fries in coke",
    "No Pubbles harmed...yet",
    "You are now breathing manually",
    "Imagine...touching grass",
    "Beep Boop I stole your soup",
    "T̸̢͈͔̱̝̓̀̔̚ḩ̷̼̱͒͛̆̓͐̓̊͘i̵̢͓͈̎̄̀̍s̸̡̬̣̲̩̿̆̂̓̅̅ ̸͕̰̗͖͇̉̋̈́̆̈́i̵̢͓͈̎̄̀̍s̴̢̨̛͙͓͖̩͐̑̓̉͘ ̸͕̰̗͖͇̉̋̈́̆̈́F̸̡̬̣̲̩̿̆̂̓̅̅i̵̢͓͈̎̄̀̍n̴̦̹̯̟͕͇̮̩̈̐̔̀̿e̴̢̨̛͙͓͖̩͐̑̓̉͘",
    "Bruh",
]

struct StyleSettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var showNewThemeAlert = false
    @State private var newThemeName = ""
    @State private var showUnsavedAlert = false
    @State private var pendingThemeSwitch: String? = nil
    @State private var arrowHovered: Int? = nil
    @State private var previewText = pillPreviewTexts.randomElement() ?? "Hello world"
    @State private var previewID = UUID()

    private var style: StyleConfig { configManager.config.style }

    private var availableFontFamilies: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            previewArea
            Divider()
            settingsForm
        }
        .navigationTitle("Style")
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
    }

    // MARK: - Preview Area (sticky, non-scrolling)

    private var previewArea: some View {
        VStack(spacing: 12) {
            // Theme picker row
            HStack {
                themePicker
                Spacer()
                if configManager.isDirty {
                    Button("Revert") {
                        configManager.resetStyleOverrides()
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        configManager.saveToActiveTheme()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Pill preview with carousel arrows
            HStack {
                carouselArrow(icon: "chevron.left", id: 0) {
                    handleThemeSelection(configManager.peekTheme(forward: false))
                }
                Spacer()
                PillPreview(style: style, text: previewText)
                    .id(previewID)
                Spacer()
                carouselArrow(icon: "chevron.right", id: 1) {
                    handleThemeSelection(configManager.peekTheme(forward: true))
                }
            }
        }
        .padding(20)
        .background(.quaternary.opacity(0.5))
        .clipped()
        .alert("New Theme", isPresented: $showNewThemeAlert) {
            TextField("Theme name", text: $newThemeName)
            Button("Create") {
                let name = newThemeName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { configManager.createTheme(name: name) }
                newThemeName = ""
            }
            Button("Cancel", role: .cancel) { newThemeName = "" }
        } message: {
            Text("Name your new theme. It will start from the default settings.")
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Save") {
                configManager.saveToActiveTheme()
                applyPendingSwitch()
            }
            Button("Revert") {
                configManager.resetStyleOverrides()
                applyPendingSwitch()
            }
            Button("Cancel", role: .cancel) {
                pendingThemeSwitch = nil
            }
        } message: {
            Text("You have unsaved changes to \(currentThemeName). Save or revert before switching themes.")
        }
    }

    private var currentThemeName: String {
        let themeFile = configManager.config.theme
        guard let themeFile, themeFile != "default" else { return "Default" }
        let themes = configManager.availableThemes()
        return themes.first(where: { $0.filename == themeFile })?.name ?? themeFile
    }

    private var themePicker: some View {
        let themes = configManager.availableThemes().filter { $0.filename != "default" }

        return Menu {
            Button("Default") { handleThemeSelection("default") }

            if !themes.isEmpty {
                Divider()
                ForEach(themes, id: \.filename) { theme in
                    Button(theme.name) { handleThemeSelection(theme.filename) }
                }
            }

            Divider()
            Button("New Theme...") { showNewThemeAlert = true }
            Button("Open Themes Folder") { configManager.openThemesFolder() }
        } label: {
            Text(currentThemeName)
        }
        .fixedSize()
    }

    private func handleThemeSelection(_ filename: String) {
        let current = configManager.config.theme ?? "default"
        guard filename != current else { return }
        if configManager.isDirty {
            pendingThemeSwitch = filename
            showUnsavedAlert = true
        } else {
            applyTheme(filename)
        }
    }

    private func applyTheme(_ filename: String) {
        previewText = pillPreviewTexts.randomElement() ?? previewText
        previewID = UUID()
        configManager.setTheme(filename == "default" ? nil : filename)
    }

    private func applyPendingSwitch() {
        if let pending = pendingThemeSwitch {
            applyTheme(pending)
            pendingThemeSwitch = nil
        }
    }

    private func carouselArrow(icon: String, id: Int, action: @escaping () -> Void) -> some View {
        let hovered = arrowHovered == id
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(hovered ? 0.08 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { arrowHovered = h ? id : nil } }
    }

    // MARK: - Settings Form

    private var settingsForm: some View {
        Form {
            AccessibilityBannerSection()
            appearanceSection
            borderSection
            shadowSection
            drawingSection
            pinnedBorderSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    private var hasGradient: Bool {
        (style.backgroundGradient?.count ?? 0) >= 2
    }

    private var appearanceSection: some View {
        Section {
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
                                // Use NSNull to explicitly override any theme-level gradient with null
                                configManager.setStyleValue("backgroundGradient", NSNull())
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

            HStack {
                Text("Text Color")
                Spacer()
                ColorPicker("", selection: textColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }

            Picker("Font Size", selection: fontSizePickerBinding) {
                ForEach([10, 12, 14, 16, 18, 20, 24], id: \.self) { size in
                    Text("\(size)pt").tag(CGFloat(size))
                }
            }

            Picker("Font Family", selection: fontFamilyBinding) {
                Text("System").tag("system")
                ForEach(availableFontFamilies, id: \.self) { family in
                    Text(family).tag(family)
                }
            }

            Picker("Scale", selection: scalePickerBinding) {
                Text("0.8x").tag(CGFloat(0.8))
                Text("1x").tag(CGFloat(1.0))
                Text("1.3x").tag(CGFloat(1.3))
                Text("1.6x").tag(CGFloat(1.6))
                Text("2x").tag(CGFloat(2.0))
            }

            Picker("Max Width", selection: maxWidthPickerBinding) {
                ForEach([150, 200, 250, 300, 400, 500, 600], id: \.self) { w in
                    Text("\(w)px").tag(CGFloat(w))
                }
            }

            TextField("Placeholder Text", text: placeholderTextBinding)
                .onSubmit { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
    }

    // MARK: - Border

    private var borderSection: some View {
        Section {
            HStack {
                Text("Border Color")
                Spacer()
                ColorPicker("", selection: borderColorWithOpacityBinding, supportsOpacity: true)
                    .labelsHidden()
            }

            Picker("Border Width", selection: borderWidthPickerBinding) {
                ForEach([0, 1, 2, 3, 4], id: \.self) { w in
                    Text("\(w)px").tag(CGFloat(w))
                }
            }

            Toggle("Sharp Corner", isOn: pointerCornerBinding)

            Picker("Corner Radius", selection: cornerRadiusPickerBinding) {
                ForEach([0, 4, 8, 12, 16, 20, 24], id: \.self) { r in
                    Text(r == 0 ? "None" : "\(r)px").tag(CGFloat(r))
                }
            }
        }
    }

    // MARK: - Shadow

    private var shadowSection: some View {
        Section {
            HStack {
                Text("Shadow Color")
                Spacer()
                ColorPicker("", selection: shadowColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }

            HStack {
                Text("Opacity")
                    .frame(width: 72, alignment: .leading)
                Slider(value: shadowOpacityBinding, in: 0...1)
                Text("\(Int(style.shadowOpacity * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("X Offset")
                    .frame(width: 72, alignment: .leading)
                Slider(value: shadowXBinding, in: -10...10)
                Text("\(Int(style.shadowX))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("Y Offset")
                    .frame(width: 72, alignment: .leading)
                Slider(value: shadowYBinding, in: -10...10)
                Text("\(Int(style.shadowY))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("Blur Radius")
                    .frame(width: 72, alignment: .leading)
                Slider(value: shadowRadiusBinding, in: 0...20)
                Text("\(Int(style.shadowRadius))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    // MARK: - Drawing

    private var drawingSection: some View {
        Section {
            HStack {
                Text("Doodle Pen Color")
                Spacer()
                ColorPicker("", selection: drawingColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }

            Picker("Doodle Pen Width", selection: drawingLineWidthPickerBinding) {
                ForEach([1, 3, 5, 8, 10], id: \.self) { w in
                    Text("\(w)px").tag(CGFloat(w))
                }
            }
        }
    }

    // MARK: - Pinned Border

    private var pinnedBorderSection: some View {
        Section {
            HStack {
                Text("Pinned Border Color")
                Spacer()
                ColorPicker("", selection: pinnedBorderColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }

            Picker("Pinned Border Width", selection: pinnedBorderWidthPickerBinding) {
                Text("None").tag(CGFloat(0))
                ForEach([2, 3, 6, 8], id: \.self) { w in
                    Text("\(w)px").tag(CGFloat(w))
                }
            }

            Picker("Pin Icon Size", selection: pinIconSizePickerBinding) {
                Text("None").tag(CGFloat(0))
                Text("Small").tag(CGFloat(12))
                Text("Medium").tag(CGFloat(14))
                Text("Large").tag(CGFloat(20))
            }
        }
    }

    // MARK: - Bindings

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
                configManager.setStyleValue("backgroundColor", Color(opaque).toHex())
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

    private var borderColorWithOpacityBinding: Binding<Color> {
        Binding(
            get: {
                (Color(hex: style.borderColor) ?? .white)
                    .opacity(style.borderOpacity)
            },
            set: { newColor in
                let nsColor = NSColor(newColor)
                let opacity = Double(nsColor.alphaComponent)
                let opaque = nsColor.withAlphaComponent(1.0)
                configManager.setStyleValue("borderColor", Color(opaque).toHex())
                configManager.setStyleValue("borderOpacity", opacity)
            }
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

    private var placeholderTextBinding: Binding<String> {
        Binding(
            get: { style.placeholderText },
            set: { configManager.setStyleValue("placeholderText", $0) }
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

    private var maxWidthPickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.maxWidth },
            set: { configManager.setStyleValue("maxWidth", $0) }
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

    private var pinnedBorderColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.pinnedBorderColor) ?? .white },
            set: { configManager.setStyleValue("pinnedBorderColor", $0.toHex()) }
        )
    }

    private var pinnedBorderWidthPickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.pinnedBorderWidth },
            set: { configManager.setStyleValue("pinnedBorderWidth", $0) }
        )
    }

    private var pinIconSizePickerBinding: Binding<CGFloat> {
        Binding(
            get: { style.pinIconSize },
            set: { configManager.setStyleValue("pinIconSize", $0) }
        )
    }
}
