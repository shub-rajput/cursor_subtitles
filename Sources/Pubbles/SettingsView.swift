import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared

    private var style: StyleConfig { configManager.config.style }
    private var behavior: BehaviorConfig { configManager.config.behavior }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                previewSection
                themeSection
                colorSection
                drawingSection
                styleSection
                behaviorSection
                footerSection
            }
            .padding(20)
        }
        .frame(width: 420, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pubbles")
                    .font(.title.bold())
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(spacing: 8) {
            PillPreview(style: style)
            shortcutRow
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var shortcutRow: some View {
        HotkeyRecorder(
            hotkey: configManager.config.hotkey,
            onSave: { configManager.setHotkey($0) }
        )
    }

    // MARK: - Themes

    private var themeSection: some View {
        SectionBox("Theme") {
            let themes = configManager.availableThemes()
            let currentTheme = configManager.config.theme

            VStack(alignment: .leading, spacing: 8) {
                FlowLayout(spacing: 6) {
                    themeChip("Default", isSelected: currentTheme == nil) {
                        configManager.setTheme(nil)
                    }
                    ForEach(themes, id: \.filename) { theme in
                        themeChip(theme.name, isSelected: currentTheme == theme.filename) {
                            configManager.setTheme(theme.filename)
                        }
                    }
                }

                if currentTheme != nil {
                    Button("Reset to theme defaults") {
                        configManager.resetStyleOverrides()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func themeChip(_ name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Colors

    private var hasGradient: Bool {
        if let g = style.backgroundGradient, g.count >= 2 { return true }
        return false
    }

    private var colorSection: some View {
        SectionBox("Colors") {
            VStack(alignment: .leading, spacing: 12) {
                if configManager.config.theme == nil {
                    colorPresets
                }

                // Solid / Gradient picker
                Picker("Background", selection: Binding(
                    get: { hasGradient ? 1 : 0 },
                    set: { newValue in
                        if newValue == 1 {
                            // Switch to gradient — seed from current bg color
                            let base = style.backgroundColor
                            configManager.setStyleValue("backgroundGradient", [base, base])
                        } else {
                            // Switch to solid — remove gradient
                            configManager.removeStyleValue("backgroundGradient")
                        }
                    }
                )) {
                    Text("Solid").tag(0)
                    Text("Gradient").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                if hasGradient {
                    gradientColorPickers
                } else {
                    HStack {
                        Text("Bubble")
                            .frame(width: 80, alignment: .leading)
                        ColorPicker("", selection: bgColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }
                }

                HStack {
                    Text("Text")
                        .frame(width: 80, alignment: .leading)
                    ColorPicker("", selection: textColorBinding, supportsOpacity: false)
                        .labelsHidden()
                }
            }
        }
    }

    private var gradientColorPickers: some View {
        GradientPicker(
            colors: Binding(
                get: { style.backgroundGradient ?? [] },
                set: { configManager.setStyleValue("backgroundGradient", $0) }
            )
        )
    }

    private var colorPresets: some View {
        let presets: [(String, String)] = [
            ("Blue", "#256CEF"), ("Red", "#991B1B"), ("Green", "#16A34A"), ("Yellow", "#E6AE00"),
            ("Pink", "#DB2777"), ("Purple", "#7C3AED"), ("Orange", "#D97706"), ("Slate", "#0F172A"),
        ]
        let currentColor = style.backgroundColor.uppercased()

        return HStack(spacing: 6) {
            ForEach(presets, id: \.1) { name, hex in
                Button {
                    configManager.setTheme(nil)
                    configManager.setColor(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if currentColor == hex.uppercased() {
                                Circle().strokeBorder(.white, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(name)
            }
        }
    }

    // MARK: - Drawing

    private var drawingSection: some View {
        SectionBox("Drawing") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Drawing color")
                        .frame(width: 100, alignment: .leading)
                    ColorPicker("", selection: drawingColorBinding, supportsOpacity: false)
                        .labelsHidden()
                }
                sliderWithField("Line width", value: drawingLineWidthBinding, range: 1...10, step: 1)
            }
        }
    }

    // MARK: - Style

    private var styleSection: some View {
        SectionBox("Style") {
            VStack(alignment: .leading, spacing: 10) {
                sliderWithField("Font size", value: fontSizeBinding, range: 8...32, step: 1)
                sliderWithField("Max width", value: maxWidthBinding, range: 150...600, step: 10)
                sliderWithField("Char limit", value: charLimitBinding, range: 10...100, step: 5)
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        SectionBox("Behavior") {
            sliderWithField("Idle timeout", value: idleTimeoutBinding, range: 1...30, step: 1, suffix: "s")
        }
    }

    private func sliderWithField(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String = ""
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)
            Slider(value: value, in: range, step: step)
            TextField("", value: value, format: .number)
                .frame(width: 44)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospacedDigit())
                .multilineTextAlignment(.center)
                .onSubmit {
                    // Clamp to valid range on submit
                    value.wrappedValue = min(max(value.wrappedValue, range.lowerBound), range.upperBound)
                }
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button("Edit Config File") {
                NSWorkspace.shared.open(
                    FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".config/pubbles/config.json")
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)

            Spacer()

            Button("Reset") {
                configManager.resetStyleOverrides()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    // MARK: - Bindings

    private var bgColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.backgroundColor) ?? .blue },
            set: { configManager.setColor($0.toHex()) }
        )
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.textColor) ?? .white },
            set: { configManager.setStyleValue("textColor", $0.toHex()) }
        )
    }

    private var drawingColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: style.drawingLineColor) ?? .red },
            set: { configManager.setStyleValue("drawingLineColor", $0.toHex()) }
        )
    }

    private var drawingLineWidthBinding: Binding<Double> {
        Binding(
            get: { Double(style.drawingLineWidth) },
            set: { configManager.setStyleValue("drawingLineWidth", $0) }
        )
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(style.fontSize) },
            set: { configManager.setStyleValue("fontSize", $0) }
        )
    }

    private var maxWidthBinding: Binding<Double> {
        Binding(
            get: { Double(style.maxWidth) },
            set: { configManager.setStyleValue("maxWidth", $0) }
        )
    }

    private var charLimitBinding: Binding<Double> {
        Binding(
            get: { Double(behavior.charLimit) },
            set: { configManager.setBehaviorValue("charLimit", Int($0)) }
        )
    }

    private var idleTimeoutBinding: Binding<Double> {
        Binding(
            get: { behavior.idleTimeout },
            set: { configManager.setBehaviorValue("idleTimeout", $0) }
        )
    }
}

// MARK: - Pill Preview

private struct PillPreview: View {
    let style: StyleConfig

    private var bgColor: Color { Color(hex: style.backgroundColor) ?? .blue }
    private var txtColor: Color { Color(hex: style.textColor) ?? .white }

    private var pillShape: UnevenRoundedRectangle {
        let r = style.cornerRadius
        return UnevenRoundedRectangle(
            topLeadingRadius: style.pointerCorner ? 2 : r,
            bottomLeadingRadius: r,
            bottomTrailingRadius: r,
            topTrailingRadius: r,
            style: .continuous
        )
    }

    @ViewBuilder
    private var pillBackground: some View {
        if let gradientColors = style.backgroundGradient, gradientColors.count >= 2 {
            LinearGradient(
                colors: gradientColors.compactMap { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(style.backgroundOpacity)
        } else {
            bgColor.opacity(style.backgroundOpacity)
        }
    }

    private var textFont: Font {
        if style.fontFamily == "system" {
            let weightMap: [String: Font.Weight] = [
                "ultraLight": .ultraLight, "thin": .thin, "light": .light,
                "regular": .regular, "medium": .medium, "semibold": .semibold,
                "bold": .bold, "heavy": .heavy, "black": .black,
            ]
            return .system(size: style.fontSize, weight: weightMap[style.fontWeight] ?? .medium)
        }
        return .custom(style.fontFamily, size: style.fontSize)
    }

    var body: some View {
        Text("Hello world")
            .font(textFont)
            .foregroundStyle(txtColor)
            .padding(.horizontal, style.paddingH)
            .padding(.vertical, style.paddingV)
            .background { pillBackground }
            .clipShape(pillShape)
            .shadow(
                color: (Color(hex: style.shadowColor) ?? .black).opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                x: style.shadowX,
                y: style.shadowY
            )
            .overlay(
                pillShape.strokeBorder(
                    (Color(hex: style.borderColor) ?? .white).opacity(style.borderOpacity),
                    lineWidth: style.borderWidth
                )
            )
    }
}

// MARK: - Section Container

private struct SectionBox<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Flow Layout for theme chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for index in row {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(index)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

// MARK: - Hotkey Recorder

private struct HotkeyRecorder: View {
    let hotkey: String
    let onSave: (String) -> Void

    @State private var isRecording = false
    @State private var recorded: String?
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Text("Shortcut:")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let recorded {
                // Recorded a new combo — show it with save/cancel
                Text(formatHotkey(recorded))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Button("Save") {
                    onSave(recorded)
                    self.recorded = nil
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Cancel") {
                    self.recorded = nil
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if isRecording {
                Text("Press shortcut...")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Button("Cancel") {
                    stopRecording()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                // Display current hotkey + record button
                Text(formatHotkey(hotkey))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Button("Record") {
                    startRecording()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])

            // Escape cancels
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            // Require at least one modifier
            guard !mods.isEmpty else { return nil }

            guard let keyName = Self.reverseKeyCodeMap[event.keyCode] else { return nil }

            var parts: [String] = []
            if mods.contains(.command) { parts.append("cmd") }
            if mods.contains(.shift) { parts.append("shift") }
            if mods.contains(.option) { parts.append("alt") }
            if mods.contains(.control) { parts.append("ctrl") }
            parts.append(keyName)

            recorded = parts.joined(separator: "+")
            stopMonitor()
            isRecording = false
            return nil // swallow the event
        }
    }

    private func stopRecording() {
        stopMonitor()
        isRecording = false
        recorded = nil
    }

    private func stopMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func formatHotkey(_ hotkey: String) -> String {
        hotkey
            .replacingOccurrences(of: "cmd", with: "\u{2318}")
            .replacingOccurrences(of: "command", with: "\u{2318}")
            .replacingOccurrences(of: "shift", with: "\u{21E7}")
            .replacingOccurrences(of: "ctrl", with: "\u{2303}")
            .replacingOccurrences(of: "control", with: "\u{2303}")
            .replacingOccurrences(of: "alt", with: "\u{2325}")
            .replacingOccurrences(of: "option", with: "\u{2325}")
            .replacingOccurrences(of: "opt", with: "\u{2325}")
            .replacingOccurrences(of: "+", with: "")
            .uppercased()
    }

    private static let reverseKeyCodeMap: [UInt16: String] = {
        let map: [String: UInt16] = [
            "/": 44, ".": 47, ",": 43, ";": 41, "'": 39, "[": 33, "]": 30,
            "\\": 42, "-": 27, "=": 24, "`": 50,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
            "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
            "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25,
            "space": 49, "return": 36, "tab": 48,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118,
            "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101,
            "f10": 109, "f11": 103, "f12": 111,
        ]
        var reversed: [UInt16: String] = [:]
        for (key, code) in map { reversed[code] = key }
        return reversed
    }()
}

// MARK: - Gradient Picker

private struct GradientPicker: NSViewRepresentable {
    @Binding var colors: [String]

    func makeNSView(context: Context) -> GradientPickerView {
        let view = GradientPickerView()
        view.onColorsChanged = { colors = $0 }
        view.colors = colors
        return view
    }

    func updateNSView(_ nsView: GradientPickerView, context: Context) {
        if nsView.colors != colors {
            nsView.colors = colors
            nsView.needsDisplay = true
        }
    }
}

@MainActor
private class GradientPickerView: NSView {
    var colors: [String] = []
    var onColorsChanged: (([String]) -> Void)?
    private var selectedIndex: Int?
    private var colorObserver: Any?

    private let barHeight: CGFloat = 20
    private let handleWidth: CGFloat = 10
    private let handleHeight: CGFloat = 24

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: handleHeight + 2)
    }

    private func location(for index: Int) -> CGFloat {
        guard colors.count >= 2 else { return 0.5 }
        return CGFloat(index) / CGFloat(colors.count - 1)
    }

    private func handleRect(for index: Int) -> NSRect {
        let trackWidth = bounds.width - handleWidth
        let x = location(for: index) * trackWidth
        let y = (bounds.height - handleHeight) / 2
        return NSRect(x: x, y: y, width: handleWidth, height: handleHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw gradient bar
        let barRect = NSRect(
            x: handleWidth / 2,
            y: (bounds.height - barHeight) / 2,
            width: bounds.width - handleWidth,
            height: barHeight
        )
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4)

        if colors.count >= 2 {
            let nsColors = colors.compactMap { NSColor.fromHex($0) }
            var locations = (0..<colors.count).map { CGFloat($0) / CGFloat(colors.count - 1) }
            if let gradient = NSGradient(colors: nsColors, atLocations: &locations, colorSpace: .sRGB) {
                ctx.saveGState()
                barPath.addClip()
                gradient.draw(in: barRect, angle: 0)
                ctx.restoreGState()
            }
        }

        // Bar border
        NSColor.white.withAlphaComponent(0.15).setStroke()
        barPath.lineWidth = 1
        barPath.stroke()

        // Draw handles
        for i in colors.indices {
            let rect = handleRect(for: i)
            let path = NSBezierPath(roundedRect: rect, xRadius: handleWidth / 2, yRadius: handleWidth / 2)

            // Fill with stop color
            (NSColor.fromHex(colors[i]) ?? .gray).setFill()
            path.fill()

            // Border
            let isSelected = selectedIndex == i
            if isSelected {
                NSColor.white.setStroke()
                path.lineWidth = 2
            } else {
                NSColor.white.withAlphaComponent(0.5).setStroke()
                path.lineWidth = 1
            }
            path.stroke()

            // Shadow
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowBlurRadius = 2
            shadow.shadowColor = .black.withAlphaComponent(0.3)
            shadow.set()
            path.fill()
            NSShadow().set() // reset
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)

        // Check if a handle was hit
        for i in colors.indices.reversed() {
            if handleRect(for: i).insetBy(dx: -3, dy: -3).contains(point) {
                selectedIndex = i
                needsDisplay = true
                openColorPanel(for: i)
                return
            }
        }

        // Tap on bar — add a stop
        let barRect = NSRect(
            x: handleWidth / 2,
            y: (bounds.height - barHeight) / 2,
            width: bounds.width - handleWidth,
            height: barHeight
        )
        if barRect.contains(point) && colors.count < 8 {
            colors.append(colors.last ?? "#000000")
            onColorsChanged?(colors)
            selectedIndex = colors.count - 1
            needsDisplay = true
            openColorPanel(for: colors.count - 1)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Delete/backspace removes selected stop
        if event.keyCode == 51 || event.keyCode == 117 { // backspace or delete
            if let index = selectedIndex, colors.count > 2, colors.indices.contains(index) {
                closeColorPanel()
                colors.remove(at: index)
                selectedIndex = nil
                onColorsChanged?(colors)
                needsDisplay = true
                return
            }
        }
        // Escape deselects
        if event.keyCode == 53 {
            closeColorPanel()
            selectedIndex = nil
            needsDisplay = true
            return
        }
        super.keyDown(with: event)
    }

    private func openColorPanel(for index: Int) {
        // Remove previous observer
        if let obs = colorObserver {
            NotificationCenter.default.removeObserver(obs)
            colorObserver = nil
        }

        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        if let color = NSColor.fromHex(colors[index]) {
            panel.color = color
        }
        panel.orderFront(nil)

        colorObserver = NotificationCenter.default.addObserver(
            forName: NSColorPanel.colorDidChangeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let idx = self.selectedIndex, self.colors.indices.contains(idx) else { return }
                let hex = panel.color.toHex()
                self.colors[idx] = hex
                self.onColorsChanged?(self.colors)
                self.needsDisplay = true
            }
        }
    }

    private func closeColorPanel() {
        if let obs = colorObserver {
            NotificationCenter.default.removeObserver(obs)
            colorObserver = nil
        }
        NSColorPanel.shared.close()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { closeColorPanel() }
    }
}

private extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((val >> 16) & 0xFF) / 255,
            green: CGFloat((val >> 8) & 0xFF) / 255,
            blue: CGFloat(val & 0xFF) / 255,
            alpha: 1
        )
    }

    func toHex() -> String {
        guard let c = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(c.redComponent * 255)
        let g = Int(c.greenComponent * 255)
        let b = Int(c.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Color toHex (Color(hex:) init is in PillView.swift)

extension Color {
    func toHex() -> String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
