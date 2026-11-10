import Foundation
import Observation

@Observable
@MainActor
final class PlanStore {
    private(set) var allTasks: [PlannedTask]
    private let file: JSONFile<[PlannedTask]>

    init(file: JSONFile<[PlannedTask]> = JSONFile(fileName: "plans.json")) {
        self.file = file
        allTasks = file.load() ?? []
    }

    func tasks(on day: Date, calendar: Calendar = .current) -> [PlannedTask] {
        allTasks
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    func task(withID id: PlannedTask.ID?) -> PlannedTask? {
        guard let id else { return nil }
        return allTasks.first { $0.id == id }
    }

    func save(_ task: PlannedTask) {
        if let index = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[index] = task
        } else {
            allTasks.append(task)
        }
        file.save(allTasks)
    }

    func delete(_ task: PlannedTask) {
        allTasks.removeAll { $0.id == task.id }
        file.save(allTasks)
    }
}
