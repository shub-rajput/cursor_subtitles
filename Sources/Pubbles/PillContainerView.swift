import SwiftUI

struct DrawingCanvasView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @ObservedObject private var configManager = ConfigManager.shared

    private var lineColor: Color {
        Color(hex: configManager.config.style.drawingLineColor) ?? .red
    }
    private var lineWidth: CGFloat {
        configManager.config.style.drawingLineWidth
    }

    var body: some View {
        // TimelineView polls currentStroke at display refresh rate while drawing.
        // currentStroke is not @Published to avoid triggering PillView redraws on every drag point.
        TimelineView(.animation(paused: !viewModel.isDrawing)) { _ in
            Canvas { context, size in
                let allStrokes = viewModel.strokes + (viewModel.currentStroke.isEmpty ? [] : [viewModel.currentStroke])
                for stroke in allStrokes {
                    guard stroke.count >= 2 else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: stroke[0].x, y: stroke[0].y))
                    for i in 1..<stroke.count {
                        path.addLine(to: CGPoint(x: stroke[i].x, y: stroke[i].y))
                    }
                    context.stroke(path, with: .color(lineColor), style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct PillContainerView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    @ObservedObject private var configManager = ConfigManager.shared
    @State private var springScale: CGFloat = 1.0
    let screenID: ObjectIdentifier

    private var fadeIn: Double { configManager.config.behavior.fadeInDuration }
    private var fadeOut: Double { configManager.config.behavior.fadeOutDuration }

    private var isActiveScreen: Bool {
        viewModel.activeScreenID == screenID
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            // Drawing canvas (renders on active screen when strokes exist and pill is visible)
            if viewModel.isVisible && isActiveScreen && (!viewModel.strokes.isEmpty || viewModel.isDrawing) {
                DrawingCanvasView(viewModel: viewModel)
                    .transition(.opacity)
            }

            if viewModel.isVisible && isActiveScreen {
                PillView(viewModel: viewModel)
                    .scaleEffect(springScale, anchor: .topLeading)
                    .onChange(of: configManager.config.style.pillScale) { oldVal, newVal in
                        guard newVal > 0 else { return }
                        springScale = oldVal / newVal
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                            springScale = 1.0
                        }
                    }
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
