import SwiftUI

/// The sidebar while a session or break is running: what it is for, how long is left, and the
/// controls to pause or end it.
struct FocusPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let timer = model.timer
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: timer.phase.symbolName)
                        .font(.system(size: 10, weight: .bold))
                    Text(timer.phase.title)
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .kerning(0.6)
                }
                .foregroundStyle(OdakPalette.onTask)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(timer.phase.isBreak ? OdakPalette.ink.opacity(0.55) : OdakPalette.accent, in: Capsule())

                if timer.status == .paused {
                    SectionLabel("Paused")
                } else if let end = timer.endsAt {
                    Text("Until \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(OdakPalette.ink.opacity(0.6))
                }
            }

            if !timer.phase.isBreak && !model.intention.isEmpty {
                Text(model.intention)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(OdakPalette.ink)
                    .lineLimit(2)
            }

            Text(verbatim: Countdown.string(for: timer.remaining))
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(OdakPalette.ink.opacity(timer.status == .paused ? 0.45 : 1))
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.3), value: Int(timer.remaining))
                .padding(.vertical, -6)

            HStack(spacing: 8) {
                Button(action: model.primaryAction) {
                    if timer.status == .paused {
                        Label("Resume", systemImage: "play.fill")
                    } else {
                        Label("Pause", systemImage: "pause.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: model.stop) {
                    if timer.phase.isBreak {
                        Text("Skip Break")
                    } else {
                        Text("Stop")
                    }
                }
                .buttonStyle(QuietButtonStyle())

                if timer.isFocusing && !model.isFocusScreenVisible {
                    Button(action: model.showFocusScreen) {
                        Label("Show Focus Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help(Text("Show Focus Screen"))
                }
            }
        }
    }
}
