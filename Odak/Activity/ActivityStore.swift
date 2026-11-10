import Foundation
import Observation

/// Which projects were worked on, in which five-minute slots, per day. Each Mac writes its own
/// file; `days` is every Mac's time laid over one another.
@Observable
@MainActor
final class ActivityStore {
    typealias Days = [String: [String: Set<Int>]]

    /// Day key (`2026-11-10`) → project → active slots.
    private(set) var days: Days = [:]
    @ObservationIgnored private var own: Days
    @ObservationIgnored private var others: Days = [:]
    @ObservationIgnored private var folder: URL
    @ObservationIgnored private let device: String
    @ObservationIgnored private var hasUnsavedChanges = false

    init(folder: URL, device: String) {
        self.folder = folder
        self.device = device
        own = Self.read(folder.appending(path: device + ".json"))
        reload()
    }

    func record(_ projects: Set<String>, at date: Date, calendar: Calendar = .current) {
        let key = Self.key(for: date, calendar: calendar)
        let slot = ActivityMath.slot(for: date, calendar: calendar)
        for project in projects where own[key]?[project]?.contains(slot) != true {
            own[key, default: [:]][project, default: []].insert(slot)
            days[key, default: [:]][project, default: []].insert(slot)
            hasUnsavedChanges = true
        }
    }

    func slots(on day: Date, calendar: Calendar = .current) -> [String: Set<Int>] {
        days[Self.key(for: day, calendar: calendar)] ?? [:]
    }

    func flush() {
        guard hasUnsavedChanges else { return }
        ownFile.save(own.mapValues { $0.mapValues { $0.sorted() } })
        hasUnsavedChanges = false
    }

    /// Reads the other Macs' files again.
    func reload() {
        others = Storage.jsonFiles(in: folder)
            .filter { $0.lastPathComponent != ownFile.url.lastPathComponent }
            .reduce(into: [:]) { Self.merge(Self.read($1), into: &$0) }
        var fresh = others
        Self.merge(own, into: &fresh)
        if fresh != days {
            days = fresh
        }
    }

    /// Moves to another folder, bringing this Mac's recorded time along.
    func relocate(to newFolder: URL) {
        guard newFolder != folder else { return }
        flush()
        folder = newFolder
        Self.merge(Self.read(ownFile.url), into: &own)
        hasUnsavedChanges = !own.isEmpty
        flush()
        reload()
    }

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        PlanFiles.key(for: date, calendar: calendar)
    }

    private var ownFile: JSONFile<[String: [String: [Int]]]> {
        JSONFile(url: folder.appending(path: device + ".json"))
    }

    private static func read(_ url: URL) -> Days {
        (JSONFile<[String: [String: [Int]]]>(url: url).load() ?? [:]).mapValues { $0.mapValues(Set.init) }
    }

    private static func merge(_ source: Days, into target: inout Days) {
        for (day, projects) in source {
            for (project, slots) in projects {
                target[day, default: [:]][project, default: []].formUnion(slots)
            }
        }
    }
}
