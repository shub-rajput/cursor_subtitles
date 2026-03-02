import SwiftUI

struct PillContainerView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        ZStack {
            Color.clear
            if viewModel.isVisible {
                PillView(viewModel: viewModel)
                    .position(
                        x: viewModel.cursorPosition.x + ConfigManager.shared.config.style.cursorOffset.x + 60,
                        y: viewModel.cursorPosition.y + ConfigManager.shared.config.style.cursorOffset.y
                    )
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isVisible)
    }
}
