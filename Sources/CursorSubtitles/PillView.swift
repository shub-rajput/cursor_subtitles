import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    private var style: StyleConfig { ConfigManager.shared.config.style }

    private var bgColor: Color { Color(hex: style.backgroundColor) ?? .green }
    private var txtColor: Color { Color(hex: style.textColor) ?? .white }

    var body: some View {
        Text(viewModel.displayText)
            .font(.system(size: style.fontSize, weight: .medium))
            .foregroundColor(viewModel.isPlaceholder ? txtColor.opacity(0.7) : txtColor)
            .padding(.horizontal, style.paddingH)
            .padding(.vertical, style.paddingV)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .fixedSize()
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
