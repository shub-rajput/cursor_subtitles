import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @State private var cursorVisible = true

    private var style: StyleConfig { ConfigManager.shared.config.style }

    private var bgColor: Color { Color(hex: style.backgroundColor) ?? .green }
    private var txtColor: Color { Color(hex: style.textColor) ?? .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Previous line — visible after Enter, fades out when typing starts
            if viewModel.showPreviousLine {
                Text(viewModel.previousLine)
                    .font(.system(size: style.fontSize, weight: .medium))
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
                        .font(.system(size: style.fontSize, weight: .medium))
                        .foregroundColor(txtColor.opacity(0.7))
                } else if viewModel.text.isEmpty {
                    // On new line, just show blinking cursor
                    Text(cursorVisible ? "|" : " ")
                        .font(.system(size: style.fontSize, weight: .light))
                        .foregroundColor(txtColor)
                } else {
                    Text(viewModel.displayText)
                        .font(.system(size: style.fontSize, weight: .medium))
                        .foregroundColor(txtColor)
                    + Text(cursorVisible && viewModel.isActive ? "|" : " ")
                        .font(.system(size: style.fontSize, weight: .light))
                        .foregroundColor(txtColor)
                }
            }
            .padding(.horizontal, style.paddingH)
            .padding(.top, viewModel.showPreviousLine ? style.paddingV / 2 : style.paddingV)
            .padding(.bottom, style.paddingV)
        }
        .frame(maxWidth: style.maxWidth, alignment: .leading)
        .fixedSize()
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .animation(nil, value: viewModel.showPreviousLine)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { _ in
                Task { @MainActor in
                    cursorVisible.toggle()
                }
            }
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
