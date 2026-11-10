import Foundation

/// The ring a task sits on. Lanes are drawn from the clock face outward in declaration order.
enum TaskLane: String, Codable, CaseIterable, Identifiable {
    case focus, meeting, personal

    var id: String { rawValue }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

struct PlannedTask: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var note: String
    var start: Date
    var end: Date
    var lane: TaskLane

    init(id: UUID = UUID(), title: String, note: String, start: Date, end: Date, lane: TaskLane) {
        self.id = id
        self.title = title
        self.note = note
        self.start = start
        self.end = end
        self.lane = lane
    }

    /// Plans saved before lanes existed have no `lane` key; they land on the focus ring.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        lane = try container.decodeIfPresent(TaskLane.self, forKey: .lane) ?? .focus
    }

    func contains(_ date: Date) -> Bool {
        start <= date && date < end
    }
}
