import SwiftUI

struct PillContainerView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    private var fadeIn: Double { ConfigManager.shared.config.behavior.fadeInDuration }
    private var fadeOut: Double { ConfigManager.shared.config.behavior.fadeOutDuration }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if viewModel.isVisible {
                PillView(viewModel: viewModel)
                    .offset(
                        x: viewModel.cursorPosition.x + ConfigManager.shared.config.style.cursorOffset.x,
                        y: viewModel.cursorPosition.y + ConfigManager.shared.config.style.cursorOffset.y
                    )
                    .transition(.opacity)
            }
        }
        .animation(viewModel.isVisible
            ? .easeInOut(duration: fadeIn)
            : .easeInOut(duration: fadeOut),
            value: viewModel.isVisible
        )
    }
}
