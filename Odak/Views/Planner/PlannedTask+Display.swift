import SwiftUI

extension TaskLane {
    var tint: Color {
        switch self {
        case .focus: PlannerPalette.dynamic(light: 0x179C56, dark: 0x2FBF70)
        case .meeting: PlannerPalette.dynamic(light: 0x4343CF, dark: 0x7272EE)
        case .personal: PlannerPalette.dynamic(light: 0xDE6628, dark: 0xEE8346)
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .focus: "Focus"
        case .meeting: "Meeting"
        case .personal: "Personal"
        }
    }

    /// Plain string for drawing in a canvas.
    var localizedName: String {
        switch self {
        case .focus: String(localized: "Focus")
        case .meeting: String(localized: "Meeting")
        case .personal: String(localized: "Personal")
        }
    }
}

extension DaySegment {
    var name: LocalizedStringKey {
        switch self {
        case .night: "Night"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }

    /// Headline for the planner, addressed to the reader.
    var headline: LocalizedStringKey {
        switch self {
        case .night: "Your night"
        case .morning: "Your morning"
        case .afternoon: "Your afternoon"
        case .evening: "Your evening"
        }
    }
}

extension PlannedTask {
    var timeRangeText: String {
        let from = start.formatted(date: .omitted, time: .shortened)
        let to = end.formatted(date: .omitted, time: .shortened)
        return "\(from) – \(to)"
    }
}
