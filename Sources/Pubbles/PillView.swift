import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var cursorVisible = true

    private let blinkPublisher = Timer.publish(every: 0.53, on: .main, in: .common).autoconnect()

    private var style: StyleConfig { configManager.config.style }
    private var scale: CGFloat { style.pillScale }

    private var bgColor: Color { Color(hex: style.backgroundColor) ?? .green }

    private var swiftUIMaterial: Material {
        switch style.vibrancy {
        case "ultraThin": return .ultraThinMaterial
        case "thin": return .thinMaterial
        case "regular": return .regularMaterial
        case "thick": return .thickMaterial
        case "ultraThick": return .ultraThickMaterial
        default: return .ultraThinMaterial
        }
    }

    @ViewBuilder
    private var pillBackground: some View {
        if style.vibrancy != nil {
            Rectangle().fill(swiftUIMaterial)
                .overlay(bgColor.opacity(style.backgroundOpacity))
        } else if let gradientColors = style.backgroundGradient,
                  gradientColors.count >= 2 {
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
    private var txtColor: Color { Color(hex: style.textColor) ?? .white }

    private static let weightMap: [String: Font.Weight] = [
        "ultraLight": .ultraLight, "thin": .thin, "light": .light,
        "regular": .regular, "medium": .medium, "semibold": .semibold,
        "bold": .bold, "heavy": .heavy, "black": .black,
    ]
    private static let weightOrder: [Font.Weight] = [
        .ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black,
    ]

    private var parsedWeight: Font.Weight {
        Self.weightMap[style.fontWeight] ?? .medium
    }

    private var cursorWeight: Font.Weight {
        guard let idx = Self.weightOrder.firstIndex(of: parsedWeight), idx > 0 else {
            return .ultraLight
        }
        return Self.weightOrder[idx - 1]
    }

    private var scaledFontSize: CGFloat { style.fontSize * scale }

    private var textFont: Font {
        if style.fontFamily == "system" {
            return .system(size: scaledFontSize, weight: parsedWeight)
        }
        return .custom(style.fontFamily, size: scaledFontSize)
    }
    private var cursorFont: Font {
        if style.fontFamily == "system" {
            return .system(size: scaledFontSize, weight: cursorWeight)
        }
        return .custom(style.fontFamily, size: scaledFontSize)
    }
    private var pillShape: UnevenRoundedRectangle {
        let r = style.cornerRadius * scale
        return UnevenRoundedRectangle(
            topLeadingRadius: style.pointerCorner ? 2 * scale : r,
            bottomLeadingRadius: r,
            bottomTrailingRadius: r,
            topTrailingRadius: r,
            style: .continuous
        )
    }

    @ViewBuilder
    private var currentLineContent: some View {
        if viewModel.isPlaceholder {
            Text(viewModel.displayText)
                .font(textFont)
                .foregroundStyle(txtColor.opacity(0.7))
        } else if viewModel.animatedChars.isEmpty && viewModel.text.isEmpty {
            Text(cursorVisible ? "|" : " ")
                .font(cursorFont)
                .foregroundStyle(txtColor)
        } else if !viewModel.animatedChars.isEmpty {
            let editID = viewModel.editingCharID
            ForEach(viewModel.animatedChars) { ac in
                if ac.character == "\n" {
                    Color.clear.frame(width: 0, height: 0)
                        .layoutValue(key: LineBreakKey.self, value: true)
                } else {
                    Text(ac.character)
                        .font(textFont)
                        .foregroundStyle(txtColor)
                        .transition(CharTransition())
                        .anchorPreference(key: EditCursorAnchorKey.self, value: .leading) {
                            ac.id == editID ? $0 : nil
                        }
                }
            }
            // End-of-line cursor: visible only when cursor is at end
            Text(cursorVisible && viewModel.isActive && editID == nil ? "|" : " ")
                .font(cursorFont)
                .foregroundStyle(txtColor)
        } else {
            // Fallback for non-animated text (hints, etc.)
            Text(viewModel.text).font(textFont).foregroundStyle(txtColor) + Text(cursorVisible && viewModel.isActive ? "|" : " ").font(cursorFont).foregroundStyle(txtColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Previous line
            if viewModel.showPreviousLine {
                HStack(spacing: 0) {
                    if !viewModel.previousLineChars.isEmpty {
                        ForEach(viewModel.previousLineChars) { ac in
                            Text(ac.character)
                                .font(textFont)
                                .foregroundStyle(txtColor.opacity(0.6))
                        }
                    } else {
                        Text(viewModel.previousLine)
                            .font(textFont)
                            .foregroundStyle(txtColor.opacity(0.6))
                    }
                }
                .padding(.horizontal, style.paddingH * scale)
                .padding(.top, style.paddingV * scale)
                .padding(.bottom, style.paddingV * scale / 2)
                .transition(.identity)
            }

            // Current line (or placeholder)
            Group {
                if configManager.config.behavior.multiLine {
                    CharFlowLayout(contentMaxWidth: (style.maxWidth - 2 * style.paddingH) * scale) {
                        currentLineContent
                    }
                } else {
                    HStack(spacing: 0) {
                        currentLineContent
                    }
                }
            }
            .padding(.horizontal, style.paddingH * scale)
            .padding(.top, viewModel.showPreviousLine ? style.paddingV * scale / 2 : style.paddingV * scale)
            .padding(.bottom, style.paddingV * scale)
            .overlayPreferenceValue(EditCursorAnchorKey.self) { anchor in
                if let anchor, viewModel.isActive {
                    GeometryReader { proxy in
                        let pt = proxy[anchor]
                        Text(cursorVisible ? "|" : " ")
                            .font(cursorFont)
                            .foregroundStyle(txtColor)
                            .fixedSize()
                            .position(x: pt.x, y: pt.y)
                    }
                }
            }
        }
        .frame(maxWidth: style.maxWidth * scale, alignment: .leading)
        .fixedSize()
        .background {
            if !style.glassEffect {
                pillBackground
            }
        }
        .clipShape(pillShape)
        .modifier(GlassEffectModifier(
            enabled: style.glassEffect,
            tint: bgColor.opacity(style.backgroundOpacity),
            shape: pillShape
        ))
        .shadow(
            color: (Color(hex: style.shadowColor) ?? .black)
                .opacity(style.shadowOpacity),
            radius: style.shadowRadius * scale,
            x: style.shadowX * scale,
            y: style.shadowY * scale
        )
        .overlay(
            pillShape
                .strokeBorder(
                    (Color(hex: style.borderColor) ?? .white)
                        .opacity(style.borderOpacity),
                    lineWidth: style.borderWidth * scale
                )
        )
        .onReceive(blinkPublisher) { _ in cursorVisible.toggle() }
        .onChange(of: viewModel.textCursorIndex) { _, _ in cursorVisible = true }
    }
}

private struct LineBreakKey: LayoutValueKey {
    static let defaultValue: Bool = false
}

private struct CharFlowLayout: Layout {
    var contentMaxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let singleLine = layout(subviews: subviews, availableWidth: .infinity).size
        if singleLine.width <= contentMaxWidth {
            return singleLine
        } else {
            return layout(subviews: subviews, availableWidth: contentMaxWidth).size
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let singleLineWidth = layout(subviews: subviews, availableWidth: .infinity).size.width
        let wrapWidth: CGFloat = singleLineWidth <= contentMaxWidth ? .infinity : contentMaxWidth
        let frames = layout(subviews: subviews, availableWidth: wrapWidth).frames
        for (index, frame) in frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(subviews: Subviews, availableWidth: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            if subview[LineBreakKey.self] {
                // Force line break — place at zero size (every subview must be placed)
                frames.append(CGRect(x: x, y: y, width: 0, height: 0))
                x = 0
                y += lineHeight
                lineHeight = 0
                continue
            }

            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > availableWidth && x > 0 {
                // Auto-wrap: start a new line
                x = 0
                y += lineHeight
                lineHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, x)
        }

        return (CGSize(width: totalWidth, height: y + lineHeight), frames)
    }
}

private struct EditCursorAnchorKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: Anchor<CGPoint>?
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = value ?? nextValue()
    }
}

private struct CharTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        let offsetY: CGFloat = switch phase {
        case .willAppear: 6
        case .identity: 0
        case .didDisappear: -6
        }
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(y: offsetY)
            .scaleEffect(phase.isIdentity ? 1 : 0.88)
            .blur(radius: phase.isIdentity ? 0 : 4)
    }
}

struct GlassEffectModifier: ViewModifier {
    let enabled: Bool
    let tint: Color
    let shape: UnevenRoundedRectangle

    func body(content: Content) -> some View {
        if enabled, #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(tint), in: shape)
        } else {
            content
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6, let hexNumber = UInt64(hexSanitized, radix: 16) else { return nil }
        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
