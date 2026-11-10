import SwiftUI

struct TodaySummary: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = model.history.sessions.sessions(on: .now)
        HStack {
            Text("Today")
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(today.count) sessions") + Text(verbatim: " · ") + Text("\(today.focusedMinutes) min")
        }
        .font(.callout)
        .monospacedDigit()
    }
}
