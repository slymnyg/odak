import AppKit
import SwiftUI

struct FocusScreenView: View {
    @Environment(AppModel.self) private var model
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>? = nil

    var body: some View {
        let timer = model.timer
        GeometryReader { geometry in
            let diameter = min(geometry.size.height * 0.6, geometry.size.width * 0.5)
            ZStack {
                backdrop(diameter: diameter)

                VStack(spacing: diameter * 0.07) {
                    Text(model.intention.isEmpty ? " " : model.intention)
                        .font(.system(size: max(diameter * 0.075, 22), weight: .bold, design: .serif))
                        .foregroundStyle(OdakPalette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: diameter * 1.6)

                    ZStack {
                        FocusRing(progress: progress, isPaused: timer.status == .paused)

                        VStack(spacing: diameter * 0.012) {
                            SectionLabel(timer.phase.title)
                            Text(verbatim: Countdown.string(for: timer.remaining))
                                .font(.system(size: diameter * 0.235, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(OdakPalette.ink.opacity(timer.status == .paused ? 0.45 : 1))
                                .contentTransition(.numericText(countsDown: true))
                                .animation(.snappy(duration: 0.3), value: Int(timer.remaining))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            statusLine
                        }
                        .padding(.horizontal, diameter * 0.14)
                    }
                    .frame(width: diameter, height: diameter)

                    controls
                        .opacity(controlsVisible ? 1 : 0)
                        .allowsHitTesting(controlsVisible)
                }

                upNext
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onContinuousHover { _ in
            revealControls()
        }
        .onAppear(perform: revealControls)
        .onDisappear {
            hideControlsTask?.cancel()
        }
    }

    /// How much of the session is behind us, 0…1.
    private var progress: Double {
        let timer = model.timer
        guard timer.duration > 0 else { return 0 }
        return min(max(1 - timer.remaining / timer.duration, 0), 1)
    }

    /// Near-black, with a faint green glow where the ring sits.
    private func backdrop(diameter: CGFloat) -> some View {
        ZStack {
            Color(red: 0.045, green: 0.05, blue: 0.06)
            RadialGradient(
                colors: [OdakPalette.accent.opacity(model.timer.status == .paused ? 0.03 : 0.11), .clear],
                center: .center,
                startRadius: diameter * 0.2,
                endRadius: diameter * 1.05
            )
            .animation(.easeInOut(duration: 0.8), value: model.timer.status)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            if model.timer.status == .paused {
                Text("Paused")
            } else if let end = model.timer.endsAt {
                Text("Until \(end.formatted(date: .omitted, time: .shortened))")
            } else {
                Text(verbatim: " ")
            }
        }
        .font(.system(size: 17, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(OdakPalette.ink.opacity(0.55))
    }

    /// What the plan holds after this session, so the next step is already known when it ends.
    @ViewBuilder
    private var upNext: some View {
        TimelineView(.everyMinute) { timeline in
            if let next = model.plans.tasks(on: timeline.date).first(where: { $0.start > timeline.date }) {
                HStack(spacing: 10) {
                    SectionLabel("Up Next")
                    RoundedRectangle(cornerRadius: 3)
                        .fill(next.lane.tint)
                        .frame(width: 10, height: 10)
                    Text(verbatim: "\(next.start.formatted(date: .omitted, time: .shortened))  \(next.title)")
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(OdakPalette.ink.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: model.primaryAction) {
                if model.timer.status == .paused {
                    Label("Resume", systemImage: "play.fill")
                } else {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: model.stop) {
                Label("End", systemImage: "stop.fill")
            }
            .buttonStyle(QuietButtonStyle())

            Button(action: model.hideFocusScreen) {
                Label("Hide (Esc)", systemImage: "menubar.arrow.up.rectangle")
            }
            .buttonStyle(QuietButtonStyle())
        }
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

/// The session as a ring: a clock-like track with a green arc that grows as time passes and a
/// bright tip marking now.
private struct FocusRing: View {
    let progress: Double
    let isPaused: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = size * 0.03
            let tint = isPaused ? OdakPalette.ink.opacity(0.4) : OdakPalette.accent
            ZStack {
                Circle()
                    .inset(by: lineWidth / 2)
                    .stroke(OdakPalette.bands[2], lineWidth: lineWidth)

                Canvas { context, canvasSize in
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let outer = size / 2 - lineWidth * 1.7
                    for step in 0..<60 {
                        let isMajor = step.isMultiple(of: 5)
                        let angle = Double(step) / 60 * 2 * .pi - .pi / 2
                        let inner = outer - size * (isMajor ? 0.026 : 0.012)
                        var tick = Path()
                        tick.move(to: CGPoint(x: center.x + outer * CGFloat(cos(angle)), y: center.y + outer * CGFloat(sin(angle))))
                        tick.addLine(to: CGPoint(x: center.x + inner * CGFloat(cos(angle)), y: center.y + inner * CGFloat(sin(angle))))
                        context.stroke(tick, with: .color(OdakPalette.ink.opacity(isMajor ? 0.45 : 0.18)), lineWidth: isMajor ? 2 : 1)
                    }
                }

                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: max(progress, 0.002))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(isPaused ? 0 : 0.55), radius: lineWidth * 0.9)

                Circle()
                    .fill(OdakPalette.onTask)
                    .frame(width: lineWidth * 0.42, height: lineWidth * 0.42)
                    .offset(y: -(size / 2 - lineWidth / 2))
                    .rotationEffect(.degrees(progress * 360))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.linear(duration: 1), value: progress)
            .animation(.easeInOut(duration: 0.4), value: isPaused)
        }
        .accessibilityHidden(true)
    }
}
