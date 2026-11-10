import SwiftUI

/// Hours worked on each day of the week, stacked by project.
struct DailyBars: View {
    let review: WeekReview
    let colors: [String: Color]

    private static let plotHeight: CGFloat = 132
    private static let gap: CGFloat = 2

    private struct Segment: Identifiable {
        let id: String
        let minutes: Int
        let color: Color
    }

    var body: some View {
        // At least an hour of headroom, so a ten-minute day doesn't fill the plot.
        let scale = CGFloat(max(review.minutesByDay.max() ?? 0, 60))
        HStack(alignment: .bottom, spacing: 14) {
            ForEach(Array(review.days.enumerated()), id: \.element) { index, day in
                let total = review.minutesByDay[index]
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 6) {
                    Text(verbatim: total > 0 ? ActivityMath.durationText(minutes: total) : " ")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(OdakPalette.ink.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    bar(segments: segments(forDay: index), total: total, scale: scale)

                    Text(day, format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 11, weight: isToday ? .bold : .medium))
                        .textCase(.uppercase)
                        .foregroundStyle(OdakPalette.ink.opacity(isToday ? 0.9 : 0.5))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide)))
                .accessibilityValue(Text(verbatim: ActivityMath.durationText(minutes: total)))
            }
        }
    }

    private func bar(segments: [Segment], total: Int, scale: CGFloat) -> some View {
        let height = Self.plotHeight * CGFloat(total) / scale
        let weight = CGFloat(max(segments.reduce(0) { $0 + $1.minutes }, 1))
        let usable = max(height - Self.gap * CGFloat(max(segments.count - 1, 0)), 0)
        return VStack(spacing: Self.gap) {
            Spacer(minLength: 0)
            // First project sits on the baseline, so the stack reads bottom-up in list order.
            ForEach(Array(segments.reversed().enumerated()), id: \.element.id) { position, segment in
                UnevenRoundedRectangle(
                    topLeadingRadius: position == 0 ? 4 : 0,
                    topTrailingRadius: position == 0 ? 4 : 0
                )
                .fill(segment.color)
                .frame(height: max(usable * CGFloat(segment.minutes) / weight, 1))
                .help(Text(verbatim: "\(segment.id) · \(ActivityMath.durationText(minutes: segment.minutes))"))
            }
        }
        .frame(maxWidth: 46)
        .frame(height: Self.plotHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OdakPalette.ink.opacity(0.18))
                .frame(height: 1)
                .offset(y: 1)
        }
    }

    /// Coloured projects in list order, then everything else folded into one "other" segment.
    private func segments(forDay index: Int) -> [Segment] {
        var result: [Segment] = []
        var otherMinutes = 0
        for project in review.projects where project.minutesByDay[index] > 0 {
            if let color = colors[project.name] {
                result.append(Segment(id: project.name, minutes: project.minutesByDay[index], color: color))
            } else {
                otherMinutes += project.minutesByDay[index]
            }
        }
        if otherMinutes > 0 {
            result.append(Segment(id: String(localized: "Other projects"), minutes: otherMinutes, color: ReviewPalette.other))
        }
        return result
    }
}
