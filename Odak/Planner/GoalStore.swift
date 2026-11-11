import Foundation
import Observation

/// Something to get done this week, without a time yet. It waits in the planner until it is
/// picked up for a focus session or placed in a day.
struct WeekGoal: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var doneAt: Date?

    var isDone: Bool { doneAt != nil }

    init(id: UUID = UUID(), title: String, createdAt: Date = .now, doneAt: Date? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.doneAt = doneAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, doneAt
    }

    // The creation time is the list order, so it is stored to the fraction of a second; the
    // shared date format would round two goals added in a row to the same moment.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = Date(timeIntervalSinceReferenceDate: try container.decode(Double.self, forKey: .createdAt))
        doneAt = try container.decodeIfPresent(Date.self, forKey: .doneAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt.timeIntervalSinceReferenceDate, forKey: .createdAt)
        try container.encodeIfPresent(doneAt, forKey: .doneAt)
    }
}

/// Goals on disk, one small file each, so two Macs adding goals never write the same file.
@Observable
@MainActor
final class GoalStore {
    private(set) var goals: [WeekGoal] = []
    @ObservationIgnored private var folder: URL

    init(folder: URL) {
        self.folder = folder
        goals = Self.load(from: folder)
    }

    /// Open goals, oldest first, then the ones finished in the week of `date`. Goals finished in
    /// an earlier week have left the list; open ones stay until they are done.
    func visible(inWeekOf date: Date = .now, calendar: Calendar = .current) -> [WeekGoal] {
        let week = calendar.dateInterval(of: .weekOfYear, for: date)
        let open = goals.filter { !$0.isDone }.sorted { $0.createdAt < $1.createdAt }
        let done = goals
            .filter { goal in goal.doneAt.map { week?.contains($0) ?? false } ?? false }
            .sorted { ($0.doneAt ?? .distantPast) < ($1.doneAt ?? .distantPast) }
        return open + done
    }

    @discardableResult
    func add(_ title: String) -> WeekGoal? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let goal = WeekGoal(title: trimmed)
        goals.append(goal)
        file(for: goal).save(goal)
        return goal
    }

    func setDone(_ isDone: Bool, for id: WeekGoal.ID, at date: Date = .now) {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[index].doneAt = isDone ? date : nil
        file(for: goals[index]).save(goals[index])
    }

    func rename(_ id: WeekGoal.ID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[index].title = trimmed
        file(for: goals[index]).save(goals[index])
    }

    /// Removes a goal. Its file goes to the Trash rather than being erased.
    func remove(_ id: WeekGoal.ID) {
        guard let goal = goals.first(where: { $0.id == id }) else { return }
        goals.removeAll { $0.id == id }
        let url = file(for: goal).url
        if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) == nil {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func reload() {
        let fresh = Self.load(from: folder)
        if fresh != goals {
            goals = fresh
        }
    }

    /// Moves to another folder, bringing this Mac's goals along.
    func relocate(to newFolder: URL) {
        guard newFolder != folder else { return }
        let mine = Set(goals.map(\.id))
        let theirs = Self.load(from: newFolder).filter { !mine.contains($0.id) }
        folder = newFolder
        for goal in goals {
            file(for: goal).save(goal)
        }
        goals = (goals + theirs).sorted { $0.createdAt < $1.createdAt }
    }

    private func file(for goal: WeekGoal) -> JSONFile<WeekGoal> {
        JSONFile(url: folder.appending(path: goal.id.uuidString + ".json"))
    }

    private static func load(from folder: URL) -> [WeekGoal] {
        var seen = Set<WeekGoal.ID>()
        return Storage.jsonFiles(in: folder)
            .compactMap { JSONFile<WeekGoal>(url: $0).load() }
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}
