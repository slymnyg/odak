import SwiftUI

/// The week at a glance: one small 24-hour ring per day, carrying that day's tasks in lane colours.
struct WeekStrip: View {
    @Binding var day: Date
    let tasks: (Date) -> [PlannedTask]

    @Namespace private var selection

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDays, id: \.self) { date in
                Button {
                    day = date
                } label: {
                    DayRing(
                        date: date,
                        tasks: tasks(date),
                        isSelected: Calendar.current.isDate(date, inSameDayAs: day),
                        selection: selection
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide)))
            }
        }
        .padding(6)
        .background(OdakPalette.bands[0], in: Capsule())
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? calendar.startOfDay(for: day)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

private struct DayRing: View {
    let date: Date
    let tasks: [PlannedTask]
    let isSelected: Bool
    let selection: Namespace.ID

    @State private var isHovered = false

    private static let diameter: CGFloat = 46
    private static let lineWidth: CGFloat = 3.5

    var body: some View {
        let isToday = Calendar.current.isDateInToday(date)
        ZStack {
            if isSelected {
                Circle()
                    .fill(OdakPalette.face)
                    .matchedGeometryEffect(id: "selection", in: selection)
            }
            Circle()
                .inset(by: Self.lineWidth / 2 + 1)
                .stroke(OdakPalette.bands[2], lineWidth: Self.lineWidth)

            ForEach(tasks) { task in
                let start = Double(DialGeometry.dayMinutes(for: task.start, on: date)) / Double(DialGeometry.minutesPerDay)
                let end = Double(DialGeometry.dayMinutes(for: task.end, on: date)) / Double(DialGeometry.minutesPerDay)
                Circle()
                    .inset(by: Self.lineWidth / 2 + 1)
                    .trim(from: start, to: max(end, start + 0.012))
                    .stroke(task.lane.tint, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: -1) {
                Text(date, format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 8, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(OdakPalette.ink.opacity(0.55))
                Text(date, format: .dateTime.day())
                    .font(.system(size: 14, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isToday ? Color.accentColor : OdakPalette.ink)
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(Circle())
        .scaleEffect(isHovered && !isSelected ? 1.08 : 1)
        .animation(.spring(duration: 0.25, bounce: 0.4), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
