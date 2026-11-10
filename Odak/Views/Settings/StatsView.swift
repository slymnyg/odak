import Charts
import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let sessions = model.history.sessions
        let totals = sessions.dailyTotals(days: 7, endingAt: .now)
        let weekMinutes = totals.reduce(0) { $0 + $1.minutes }
        Form {
            Section("Last 7 Days") {
                Chart(totals) { total in
                    BarMark(
                        x: .value("Day", total.day, unit: .day),
                        y: .value("Minutes", total.minutes)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 180)
            }

            Section {
                LabeledContent("Focused this week") {
                    Text("\(weekMinutes) min")
                }
                LabeledContent("Total sessions") {
                    Text(verbatim: "\(sessions.count)")
                }
                LabeledContent("Current streak") {
                    Text("\(sessions.streak(asOf: .now)) days")
                }
            }
        }
        .formStyle(.grouped)
        .monospacedDigit()
    }
}
