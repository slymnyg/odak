import SwiftUI

struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.showSeconds) private var showSeconds = Preferences.Default.showSeconds

    var body: some View {
        let timer = model.timer
        if timer.isActive {
            HStack(spacing: 4) {
                Image(systemName: timer.status == .paused ? "pause.circle.fill" : timer.phase.symbolName)
                Text(verbatim: timeText)
                    .monospacedDigit()
            }
        } else {
            Image(systemName: timer.phase.symbolName)
        }
    }

    private var timeText: String {
        if showSeconds {
            return Countdown.string(for: model.timer.remaining)
        }
        return String(localized: "\(Countdown.minutesRemaining(for: model.timer.remaining)) min")
    }
}
