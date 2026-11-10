import Foundation
import Observation

/// Which projects were worked on, in which five-minute slots, per day.
@Observable
@MainActor
final class ActivityStore {
    /// Day key (`2026-11-10`) → project → active slots.
    private(set) var days: [String: [String: Set<Int>]]
    private let file: JSONFile<[String: [String: [Int]]]>
    @ObservationIgnored private var hasUnsavedChanges = false

    init(file: JSONFile<[String: [String: [Int]]]> = JSONFile(fileName: "activity.json")) {
        self.file = file
        days = (file.load() ?? [:]).mapValues { $0.mapValues(Set.init) }
    }

    func record(_ projects: Set<String>, at date: Date, calendar: Calendar = .current) {
        let key = Self.key(for: date, calendar: calendar)
        let slot = ActivityMath.slot(for: date, calendar: calendar)
        for project in projects where days[key]?[project]?.contains(slot) != true {
            days[key, default: [:]][project, default: []].insert(slot)
            hasUnsavedChanges = true
        }
    }

    func slots(on day: Date, calendar: Calendar = .current) -> [String: Set<Int>] {
        days[Self.key(for: day, calendar: calendar)] ?? [:]
    }

    func flush() {
        guard hasUnsavedChanges else { return }
        file.save(days.mapValues { $0.mapValues { $0.sorted() } })
        hasUnsavedChanges = false
    }

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
