import AppKit
import SwiftUI

struct FocusScreenView: View {
    @Environment(AppModel.self) private var model
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>? = nil

    var body: some View {
        let timer = model.timer
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                if !model.intention.isEmpty {
                    Text(model.intention)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }

                Text(verbatim: Countdown.string(for: timer.remaining))
                    .font(.system(size: 168, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)

                Text("Paused")
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .opacity(timer.status == .paused ? 1 : 0)

                controls
                    .opacity(controlsVisible ? 1 : 0)
                    .allowsHitTesting(controlsVisible)
            }
            .padding(80)
        }
        .environment(\.colorScheme, .dark)
        .onContinuousHover { _ in
            revealControls()
        }
        .onAppear(perform: revealControls)
        .onDisappear {
            hideControlsTask?.cancel()
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: model.primaryAction) {
                if model.timer.status == .paused {
                    Label("Resume", systemImage: "play.fill")
                } else {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            Button(action: model.stop) {
                Label("End", systemImage: "stop.fill")
            }
            Button(action: model.hideFocusScreen) {
                Label("Hide (Esc)", systemImage: "menubar.arrow.up.rectangle")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func revealControls() {
        withAnimation(.easeOut(duration: 0.2)) {
            controlsVisible = true
        }
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.6)) {
                controlsVisible = false
            }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }
}
