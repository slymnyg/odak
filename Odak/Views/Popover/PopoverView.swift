import AppKit
import SwiftUI

struct PopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IntentionField(model: model)

            TimerSection()

            if model.timer.status == .idle && model.timer.phase == .focus {
                DurationPicker()
            }

            Divider()
            BlockingSection()
            Divider()
            TodaySummary()
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var footer: some View {
        HStack {
            Button("Plan Your Day…") {
                model.showPlanner()
            }
            Spacer()
            SettingsLink {
                Text("Settings…")
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
}

private struct IntentionField: View {
    @Bindable var model: AppModel

    var body: some View {
        TextField("What are you working on?", text: $model.intention)
            .textFieldStyle(.roundedBorder)
    }
}
