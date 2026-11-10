import Foundation

/// Activity is kept as five-minute slots of the day in which a project's files changed.
enum ActivityMath {
    static let slotMinutes = 5
    static let slotsPerDay = 24 * 60 / slotMinutes
    /// Pauses up to this long between two active slots still count as work: reading, thinking, a build.
    static let maxGapSlots = 2

    static func slot(for date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return ((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / slotMinutes
    }

    /// The slots with short pauses between them filled in.
    static func filled(_ slots: Set<Int>) -> Set<Int> {
        var result = slots
        let ordered = slots.sorted()
        for (earlier, later) in zip(ordered, ordered.dropFirst()) where later - earlier - 1 <= maxGapSlots {
            result.formUnion(earlier..<later)
        }
        return result
    }

    static func minutes(_ slots: Set<Int>) -> Int {
        filled(slots).count * slotMinutes
    }

    /// "3h 20m" in the reader's language; an em dash for nothing.
    static func durationText(minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
