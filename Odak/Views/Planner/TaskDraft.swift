import Foundation

struct TaskDraft: Identifiable {
    static let slotsPerDay = DialGeometry.minutesPerDay / DialGeometry.slotMinutes

    let id: UUID
    let day: Date
    let isNew: Bool
    var title: String
    var note: String
    var startSlot: Int
    var endSlot: Int
    var lane: TaskLane

    init(day: Date, startSlot: Int, endSlot: Int, lane: TaskLane = .focus) {
        id = UUID()
        self.day = day
        isNew = true
        title = ""
        note = ""
        self.startSlot = startSlot
        self.endSlot = endSlot
        self.lane = lane
    }

    init(task: PlannedTask, day: Date) {
        id = task.id
        self.day = day
        isNew = false
        title = task.title
        note = task.note
        startSlot = DialGeometry.dayMinutes(for: task.start, on: day) / DialGeometry.slotMinutes
        endSlot = DialGeometry.dayMinutes(for: task.end, on: day) / DialGeometry.slotMinutes
        lane = task.lane
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedTitle.isEmpty && endSlot > startSlot
    }

    func slotDate(_ slot: Int) -> Date {
        DialGeometry.date(forDayMinutes: slot * DialGeometry.slotMinutes, on: day)
    }

    func makeTask() -> PlannedTask {
        PlannedTask(
            id: id,
            title: trimmedTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            start: slotDate(startSlot),
            end: slotDate(endSlot),
            lane: lane
        )
    }
}
