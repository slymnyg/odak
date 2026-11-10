import SwiftUI

struct TimerSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.focusMinutes) private var focusMinutes = Preferences.Default.focusMinutes
    @AppStorage(Preferences.Key.shortBreakMinutes) private var shortBreakMinutes = Preferences.Default.shortBreakMinutes
    @AppStorage(Preferences.Key.longBreakMinutes) private var longBreakMinutes = Preferences.Default.longBreakMinutes

    var body: some View {
        let timer = model.timer
        VStack(spacing: 10) {
            HStack {
                Label(timer.phase.title, systemImage: timer.phase.symbolName)
                Spacer()
                if timer.status == .paused {
                    Text("Paused")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(verbatim: Countdown.string(for: displayedSeconds))
                .font(.system(size: 48, weight: .light))
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: model.primaryAction) {
                    Text(primaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                if timer.isActive || timer.phase.isBreak {
                    Button(action: model.stop) {
                        if timer.isActive {
                            Text("Stop")
                        } else {
                            Text("Skip Break")
                        }
                    }
                }
            }
            .controlSize(.large)

            if timer.isFocusing && !model.isFocusScreenVisible {
                Button("Show Focus Screen", action: model.showFocusScreen)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
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
