import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var cursorVisible = true

    private let blinkPublisher = Timer.publish(every: 0.53, on: .main, in: .common).autoconnect()

    private var style: StyleConfig { configManager.config.style }

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

    private var textFont: Font {
        if style.fontFamily == "system" {
            return .system(size: style.fontSize, weight: parsedWeight)
        }
        return .custom(style.fontFamily, size: style.fontSize)
    }
    private var cursorFont: Font {
        if style.fontFamily == "system" {
            return .system(size: style.fontSize, weight: cursorWeight)
        }
        return .custom(style.fontFamily, size: style.fontSize)
    }
    private var pillShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: style.pointerCorner ? 2 : style.cornerRadius,
            bottomLeadingRadius: style.cornerRadius,
            bottomTrailingRadius: style.cornerRadius,
            topTrailingRadius: style.cornerRadius,
            style: .continuous
        )
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
                .padding(.horizontal, style.paddingH)
                .padding(.top, style.paddingV)
                .padding(.bottom, style.paddingV / 2)
                .transition(.identity)
            }

            // Current line (or placeholder)
            HStack(spacing: 0) {
                if viewModel.isPlaceholder {
                    Text(viewModel.displayText)
                        .font(textFont)
                        .foregroundStyle(txtColor.opacity(0.7))
                } else if viewModel.animatedChars.isEmpty && viewModel.text.isEmpty {
                    Text(cursorVisible ? "|" : " ")
                        .font(cursorFont)
                        .foregroundStyle(txtColor)
                } else if !viewModel.animatedChars.isEmpty {
                    ForEach(viewModel.animatedChars) { ac in
                        Text(ac.character)
                            .font(textFont)
                            .foregroundStyle(txtColor)
                            .transition(CharTransition())
                    }
                    Text(cursorVisible && viewModel.isActive ? "|" : " ")
                        .font(cursorFont)
                        .foregroundStyle(txtColor)
                } else {
                    // Fallback for non-animated text (hints, etc.)
                    Text(viewModel.text)
                        .font(textFont)
                        .foregroundStyle(txtColor)
                    + Text(cursorVisible && viewModel.isActive ? "|" : " ")
                        .font(cursorFont)
                        .foregroundStyle(txtColor)
                }
            }
            .padding(.horizontal, style.paddingH)
            .padding(.top, viewModel.showPreviousLine ? style.paddingV / 2 : style.paddingV)
            .padding(.bottom, style.paddingV)
        }
        .frame(maxWidth: style.maxWidth, alignment: .leading)
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
            radius: style.shadowRadius,
            x: style.shadowX,
            y: style.shadowY
        )
        .overlay(
            pillShape
                .strokeBorder(
                    (Color(hex: style.borderColor) ?? .white)
                        .opacity(style.borderOpacity),
                    lineWidth: style.borderWidth
                )
        )
        .onReceive(blinkPublisher) { _ in cursorVisible.toggle() }
    }
}

private struct CharTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase == .willAppear ? 0 : 1)
            .offset(y: phase == .willAppear ? 6 : 0)
            .scaleEffect(phase == .willAppear ? 0.88 : 1)
            .blur(radius: phase == .willAppear ? 4 : 0)
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
