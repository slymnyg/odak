import SwiftUI

struct TodaySummary: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = model.history.sessions.sessions(on: .now)
        HStack(alignment: .firstTextBaseline) {
            SectionLabel("Today")
            Spacer()
            (Text("\(today.count) sessions") + Text(verbatim: " · ") + Text("\(today.focusedMinutes) min"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(OdakPalette.ink.opacity(0.8))
        }
    }
}
