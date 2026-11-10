import Foundation

struct Session: Codable, Identifiable, Equatable {
    var id = UUID()
    let start: Date
    let end: Date
    let plannedMinutes: Int
    let actualMinutes: Int
    let intention: String?
}

extension Session {
    init(completion: FocusTimer.Completion, intention: String) {
        let trimmed = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            start: completion.startedAt,
            end: completion.endedAt,
            plannedMinutes: Int((completion.plannedDuration / 60).rounded()),
            actualMinutes: Int((completion.activeDuration / 60).rounded()),
            intention: trimmed.isEmpty ? nil : trimmed
        )
    }
}
