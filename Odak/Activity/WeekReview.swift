import Foundation

/// One week of tracked work, summed up per day and per project.
struct WeekReview: Equatable {
    struct Project: Identifiable, Equatable {
        let name: String
        let minutesByDay: [Int]

        var id: String { name }
        var minutes: Int { minutesByDay.reduce(0, +) }
    }

    let days: [Date]
    /// Worked minutes per day. Projects worked on at the same time are counted once.
    let minutesByDay: [Int]
    /// Most time first.
    let projects: [Project]

    var totalMinutes: Int { minutesByDay.reduce(0, +) }

    init(days: [Date], slots: (Date) -> [String: Set<Int>]) {
        self.days = days
        let perDay = days.map(slots)
        minutesByDay = perDay.map { ActivityMath.minutes($0.values.reduce(into: Set<Int>()) { $0.formUnion($1) }) }
        projects = Set(perDay.flatMap(\.keys))
            .map { name in Project(name: name, minutesByDay: perDay.map { ActivityMath.minutes($0[name] ?? []) }) }
            .sorted { ($0.minutes, $1.name) > ($1.minutes, $0.name) }
    }

    static func days(ofWeekContaining date: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
