import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @State private var cursorVisible = true

    private var style: StyleConfig { ConfigManager.shared.config.style }

    private var bgColor: Color { Color(hex: style.backgroundColor) ?? .green }
    private var txtColor: Color { Color(hex: style.textColor) ?? .white }

    private var dynamicCornerRadius: CGFloat {
        let lineCount = viewModel.displayText.components(separatedBy: "\n").count
        if lineCount > 1 {
            return min(style.cornerRadius, 16)
        }
        return style.cornerRadius
    }

    var body: some View {
        HStack(spacing: 0) {
            if viewModel.isPlaceholder {
                Text(viewModel.displayText)
                    .font(.system(size: style.fontSize, weight: .medium))
                    .foregroundColor(txtColor.opacity(0.7))
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
        .padding(.vertical, style.paddingV)
        .frame(maxWidth: style.maxWidth, alignment: .leading)
        .fixedSize()
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: dynamicCornerRadius, style: .continuous))
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
