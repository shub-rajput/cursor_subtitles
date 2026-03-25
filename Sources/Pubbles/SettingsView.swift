import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case style = "Style"
    case hotkeys = "Hotkeys"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .style: "paintpalette.fill"
        case .hotkeys: "keyboard.fill"
        case .settings: "gearshape.fill"
        case .about: "info.circle.fill"
        }
    }

}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .style

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 200)
        } detail: {
            detailView
        }
    }

    private var sidebar: some View {
        List(SettingsTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Text("Pubbles")
                    .font(.headline)
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .style:
            StyleSettingsView()
        case .hotkeys:
            HotkeysSettingsView()
        case .settings:
            GeneralSettingsView()
        case .about:
            placeholderView("About")
        }
    }

    private func placeholderView(_ title: String) -> some View {
        VStack {
            Spacer()
            Text("\(title) — Coming Soon")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
    }
}

// MARK: - Pill Preview

struct PillPreview: View {
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

// MARK: - Gradient Picker

struct GradientPicker: NSViewRepresentable {
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
class GradientPickerView: NSView {
    var colors: [String] = []
    var onColorsChanged: (([String]) -> Void)?
    private var selectedIndex: Int?
    private var colorObserver: Any?

    private let barHeight: CGFloat = 14
    private let handleWidth: CGFloat = 8
    private let handleHeight: CGFloat = 20

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

extension NSColor {
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
