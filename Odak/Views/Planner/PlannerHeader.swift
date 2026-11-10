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

            Spacer(minLength: 0)

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(CornerButtonStyle())
            .help(Text("Settings"))
            .accessibilityLabel(Text("Settings"))
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A bare icon that keeps to itself until the pointer comes near.
private struct CornerButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(OdakPalette.ink.opacity(isHovered ? 0.85 : 0.32))
            .frame(width: 30, height: 30)
            .background(OdakPalette.bands[0].opacity(isHovered ? 1 : 0), in: Circle())
            .rotationEffect(.degrees(isHovered ? 30 : 0))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .contentShape(Circle())
            .animation(.snappy(duration: 0.25), value: isHovered)
            .onHover { isHovered = $0 }
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
