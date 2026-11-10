import AppKit
import SwiftUI

struct PopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TimerSection()

            BlockingSection()
            TodaySummary()

            Rectangle()
                .fill(OdakPalette.ink.opacity(0.08))
                .frame(height: 1)

            footer
        }
        .padding(18)
        .frame(width: 320)
        .background(OdakPalette.paper)
        .tint(OdakPalette.accent)
        .animation(.snappy(duration: 0.25), value: model.timer.status)
        .animation(.snappy(duration: 0.25), value: model.timer.phase)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Button {
                model.showPlanner()
            } label: {
                Label("Plan Your Day…", systemImage: "circle.lefthalf.filled")
            }
            Spacer()
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .buttonStyle(FooterButtonStyle())
    }
}
