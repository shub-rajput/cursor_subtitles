import SwiftUI

struct PillContainerView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @ObservedObject private var configManager = ConfigManager.shared
    let screenID: ObjectIdentifier

    private var fadeIn: Double { configManager.config.behavior.fadeInDuration }
    private var fadeOut: Double { configManager.config.behavior.fadeOutDuration }

    private var isActiveScreen: Bool {
        viewModel.activeScreenID == screenID
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if viewModel.isVisible && isActiveScreen {
                PillView(viewModel: viewModel)
                    .offset(
                        x: viewModel.cursorPosition.x + configManager.config.style.cursorOffset.x,
                        y: viewModel.cursorPosition.y + configManager.config.style.cursorOffset.y
                    )
                    .transition(.opacity)
            }
        }
        .animation(viewModel.isVisible && isActiveScreen
            ? .smooth(duration: fadeIn)
            : .easeOut(duration: fadeOut),
            value: viewModel.isVisible && isActiveScreen
        )
    }
}
