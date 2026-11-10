import SwiftUI

struct DurationPicker: View {
    @AppStorage(Preferences.Key.focusMinutes) private var minutes = Preferences.Default.focusMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Duration", selection: $minutes) {
                ForEach(Preferences.durationPresets, id: \.self) { preset in
                    Text(verbatim: "\(preset)").tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 6) {
                Text("Custom")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("Minutes", value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                Stepper("Minutes", value: $minutes, in: Preferences.focusRange)
                    .labelsHidden()
                Text("min")
                    .foregroundStyle(.secondary)
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
