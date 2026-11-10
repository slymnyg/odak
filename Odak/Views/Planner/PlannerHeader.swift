import SwiftUI

/// Headline for the visible part of the day, with the date badge and the segment switcher.
struct PlannerHeader: View {
    @Binding var day: Date
    @Binding var segment: DaySegment

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            DateBadge(day: $day)

            VStack(alignment: .leading, spacing: 10) {
                Text(segment.headline)
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(OdakPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .id(segment)
                    .transition(.blurReplace)

                ChipPicker(options: DaySegment.allCases, selection: $segment) { Text($0.name) }
                .padding(.leading, -10)
            }
        }
    }
}

/// Weekday and day number on a round badge. Clicking it returns to today; the chevrons step a day.
private struct DateBadge: View {
    @Binding var day: Date

    var body: some View {
        HStack(spacing: 2) {
            stepButton(systemImage: "chevron.left", help: "Previous Day", days: -1)

            Button {
                day = Calendar.current.startOfDay(for: .now)
            } label: {
                VStack(spacing: -2) {
                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(OdakPalette.ink.opacity(0.6))
                    Text(day, format: .dateTime.day())
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(OdakPalette.ink)
                        .contentTransition(.numericText())
                }
                .frame(width: 68, height: 68)
                .background(OdakPalette.face, in: Circle())
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(Text("Today"))
            .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month(.wide)))

            stepButton(systemImage: "chevron.right", help: "Next Day", days: 1)
        }
    }

    private func stepButton(systemImage: String, help: LocalizedStringKey, days: Int) -> some View {
        Button {
            if let shifted = Calendar.current.date(byAdding: .day, value: days, to: day) {
                day = shifted
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(OdakPalette.ink.opacity(0.45))
                .frame(width: 20, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(help))
        .accessibilityLabel(Text(help))
    }
}
