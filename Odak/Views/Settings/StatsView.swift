import Charts
import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let sessions = model.history.sessions
        let totals = sessions.dailyTotals(days: 7, endingAt: .now)
        let weekMinutes = totals.reduce(0) { $0 + $1.minutes }
        Form {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: 32) {
                    figure(ActivityMath.durationText(minutes: weekMinutes), "Focused this week")
                    figure("\(sessions.count)", "Total sessions")
                    figure("\(sessions.streak(asOf: .now))", "Day streak")
                }
                .padding(.vertical, 6)
            }

            Section("Last 7 Days") {
                Chart(totals) { total in
                    BarMark(
                        x: .value("Day", total.day, unit: .day),
                        y: .value("Minutes", total.minutes),
                        width: .ratio(0.5)
                    )
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                    .foregroundStyle(OdakPalette.accent)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(OdakPalette.ink.opacity(0.08))
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
                .padding(.vertical, 6)

                Text("Focus sessions only. For time per project, open the week in review from the planner.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .monospacedDigit()
    }

    private func figure(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(OdakPalette.ink)
            SectionLabel(label)
        }
    }
}
