import Foundation
import Observation

@Observable
@MainActor
final class PlanStore {
    private(set) var allTasks: [PlannedTask]
    @ObservationIgnored private var folder: URL

    init(folder: URL) {
        self.folder = folder
        allTasks = PlanFiles.load(from: folder)
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
        // Pick up what another Mac wrote first, so this write does not undo it.
        reload()
        var days: Set<String> = [PlanFiles.key(for: task.start)]
        if let index = allTasks.firstIndex(where: { $0.id == task.id }) {
            days.insert(PlanFiles.key(for: allTasks[index].start))
            allTasks[index] = task
        } else {
            allTasks.append(task)
        }
        PlanFiles.write(allTasks, to: folder, days: days)
    }

    func delete(_ task: PlannedTask) {
        reload()
        guard let existing = allTasks.first(where: { $0.id == task.id }) else { return }
        allTasks.removeAll { $0.id == task.id }
        PlanFiles.write(allTasks, to: folder, days: [PlanFiles.key(for: existing.start)])
    }

    /// Reads the folder again, after it changed underneath the app.
    func reload() {
        let fresh = PlanFiles.load(from: folder)
        if Set(fresh) != Set(allTasks) {
            allTasks = fresh
        }
    }

    /// Moves to another folder, bringing this Mac's plans along. Tasks already there are kept;
    /// where both sides have the same task, this Mac's version wins.
    func relocate(to newFolder: URL) {
        guard newFolder != folder else { return }
        let mine = Set(allTasks.map(\.id))
        allTasks += PlanFiles.load(from: newFolder).filter { !mine.contains($0.id) }
        folder = newFolder
        PlanFiles.write(allTasks, to: newFolder)
    }
}
