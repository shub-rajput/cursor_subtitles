import SwiftUI

struct PillContainerView: View {
    @ObservedObject var viewModel: SubtitleViewModel

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
        .animation(.easeInOut(duration: 0.2), value: viewModel.isVisible)
    }
}
