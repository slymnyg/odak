import SwiftUI

struct DurationPicker: View {
    @AppStorage(Preferences.Key.focusMinutes) private var minutes = Preferences.Default.focusMinutes

    var body: some View {
        HStack(spacing: 8) {
            ChipPicker(options: Preferences.durationPresets, selection: $minutes, fillsWidth: true) { preset in
                Text(verbatim: "\(preset)")
                    .monospacedDigit()
            }
            .padding(3)
            .background(OdakPalette.bands[0], in: Capsule())

            HStack(spacing: 3) {
                TextField("Minutes", value: $minutes, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OdakPalette.ink)
                    .frame(width: 30)
                Text("min")
                    .font(.system(size: 12))
                    .foregroundStyle(OdakPalette.ink.opacity(0.5))
                Stepper("Minutes", value: $minutes, in: Preferences.focusRange, step: 5)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
        .onChange(of: minutes) { _, newValue in
            let clamped = Preferences.clamped(newValue, to: Preferences.focusRange)
            if clamped != newValue {
                minutes = clamped
            }
        }
    }
}
