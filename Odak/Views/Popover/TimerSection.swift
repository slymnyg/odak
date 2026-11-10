import SwiftUI

struct TimerSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.focusMinutes) private var focusMinutes = Preferences.Default.focusMinutes
    @AppStorage(Preferences.Key.shortBreakMinutes) private var shortBreakMinutes = Preferences.Default.shortBreakMinutes
    @AppStorage(Preferences.Key.longBreakMinutes) private var longBreakMinutes = Preferences.Default.longBreakMinutes

    var body: some View {
        @Bindable var model = model
        let timer = model.timer
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: timer.phase.symbolName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(OdakPalette.ink.opacity(0.5))
                SectionLabel(timer.phase.title)
                Spacer()
                if timer.status == .paused {
                    SectionLabel("Paused")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: Countdown.string(for: displayedSeconds))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OdakPalette.ink.opacity(timer.status == .paused ? 0.45 : 1))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.3), value: Int(displayedSeconds))
                    .frame(maxWidth: .infinity, alignment: .leading)

                progressBar
            }

            TextField("What are you working on?", text: $model.intention)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(OdakPalette.ink)
                .padding(.bottom, 7)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(OdakPalette.ink.opacity(0.15))
                        .frame(height: 1)
                }

            if timer.status == .idle && timer.phase == .focus {
                DurationPicker()
            }

            HStack(spacing: 8) {
                Button(action: model.primaryAction) {
                    Text(primaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)

                if timer.isActive || timer.phase.isBreak {
                    Button(action: model.stop) {
                        if timer.isActive {
                            Text("Stop")
                        } else {
                            Text("Skip Break")
                        }
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }

            if timer.isFocusing && !model.isFocusScreenVisible {
                Button(action: model.showFocusScreen) {
                    Label("Show Focus Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(FooterButtonStyle())
            }
        }
    }

    /// How much of the session is behind you. Empty while nothing is running.
    private var progressBar: some View {
        let timer = model.timer
        let elapsed = timer.isActive && timer.duration > 0 ? 1 - timer.remaining / timer.duration : 0
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(OdakPalette.bands[1])
                Capsule()
                    .fill(timer.phase.isBreak ? OdakPalette.ink.opacity(0.5) : OdakPalette.accent)
                    .frame(width: max(geometry.size.width * min(max(elapsed, 0), 1), timer.isActive ? 5 : 0))
                    .animation(.linear(duration: 1), value: elapsed)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private var displayedSeconds: TimeInterval {
        let timer = model.timer
        if timer.isActive {
            return timer.remaining
        }
        let minutes = switch timer.phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    private var primaryTitle: LocalizedStringKey {
        switch (model.timer.status, model.timer.phase.isBreak) {
        case (.idle, false): "Start Focus"
        case (.idle, true): "Start Break"
        case (.running, _): "Pause"
        case (.paused, _): "Resume"
        }
    }
}
