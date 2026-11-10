import Foundation

struct DailyTotal: Identifiable, Equatable {
    let day: Date
    let minutes: Int

    var id: Date { day }
}

extension Collection where Element == Session {
    func sessions(on day: Date, calendar: Calendar = .current) -> [Session] {
        filter { calendar.isDate($0.start, inSameDayAs: day) }
    }

    var focusedMinutes: Int {
        reduce(0) { $0 + $1.actualMinutes }
    }

    func dailyTotals(days: Int, endingAt date: Date, calendar: Calendar = .current) -> [DailyTotal] {
        let today = calendar.startOfDay(for: date)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyTotal(day: day, minutes: sessions(on: day, calendar: calendar).focusedMinutes)
        }
    }

    func streak(asOf date: Date, calendar: Calendar = .current) -> Int {
        let activeDays = Set(map { calendar.startOfDay(for: $0.start) })
        var day = calendar.startOfDay(for: date)
        if !activeDays.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        var count = 0
        while activeDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
