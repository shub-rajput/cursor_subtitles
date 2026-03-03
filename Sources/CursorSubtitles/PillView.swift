import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @State private var cursorVisible = true
    @State private var blinkTimer: Timer?

    private var style: StyleConfig { ConfigManager.shared.config.style }

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
    private var textFont: Font {
        if style.fontFamily == "system" {
            return .system(size: style.fontSize, weight: .medium)
        }
        return .custom(style.fontFamily, size: style.fontSize)
    }
    private var cursorFont: Font {
        if style.fontFamily == "system" {
            return .system(size: style.fontSize, weight: .light)
        }
        return .custom(style.fontFamily, size: style.fontSize)
    }
    private var pillShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: style.pointerCorner ? 0 : style.cornerRadius,
            bottomLeadingRadius: style.cornerRadius,
            bottomTrailingRadius: style.cornerRadius,
            topTrailingRadius: style.cornerRadius,
            style: .continuous
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Previous line — visible after Enter, fades out when typing starts
            if viewModel.showPreviousLine {
                Text(viewModel.previousLine)
                    .font(textFont)
                    .foregroundColor(txtColor)
                    .padding(.horizontal, style.paddingH)
                    .padding(.top, style.paddingV)
                    .padding(.bottom, style.paddingV / 2)
                    .transition(.opacity)
            }

            // Current line (or placeholder)
            HStack(spacing: 0) {
                if viewModel.isPlaceholder {
                    Text(viewModel.displayText)
                        .font(textFont)
                        .foregroundColor(txtColor.opacity(0.7))
                } else if viewModel.text.isEmpty {
                    // On new line, just show blinking cursor
                    Text(cursorVisible ? "|" : " ")
                        .font(cursorFont)
                        .foregroundColor(txtColor)
                } else {
                    Text(viewModel.displayText)
                        .font(textFont)
                        .foregroundColor(txtColor)
                    + Text(cursorVisible && viewModel.isActive ? "|" : " ")
                        .font(cursorFont)
                        .foregroundColor(txtColor)
                }
            }
            .padding(.horizontal, style.paddingH)
            .padding(.top, viewModel.showPreviousLine ? style.paddingV / 2 : style.paddingV)
            .padding(.bottom, style.paddingV)
        }
        .frame(maxWidth: style.maxWidth, alignment: .leading)
        .fixedSize()
        .background(pillBackground)
        .clipShape(pillShape)
        .modifier(GlassEffectModifier(
            enabled: style.glassEffect,
            tint: bgColor.opacity(style.backgroundOpacity),
            shape: pillShape
        ))
        .overlay(
            pillShape
                .strokeBorder(
                    (Color(hex: style.borderColor) ?? .white)
                        .opacity(style.borderOpacity),
                    lineWidth: style.borderWidth
                )
        )
        .shadow(
            color: (Color(hex: style.shadowColor) ?? .black)
                .opacity(style.shadowOpacity),
            radius: style.shadowRadius,
            x: style.shadowX,
            y: style.shadowY
        )
        .animation(nil, value: viewModel.showPreviousLine)
        .onAppear {
            blinkTimer?.invalidate()
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { _ in
                Task { @MainActor in
                    cursorVisible.toggle()
                }
            }
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
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
