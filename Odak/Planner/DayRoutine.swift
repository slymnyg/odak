import Foundation

/// The shape of an ordinary day, set once: when work starts and ends, and the breaks that are
/// always there. Planning the day starts from this instead of from an empty dial.
struct DayRoutine: Codable, Equatable {
    /// Minutes of the day between which tasks are placed.
    var workStart = 9 * 60
    var workEnd = 18 * 60
    var blocks: [Block] = Block.suggested

    struct Block: Codable, Equatable, Identifiable {
        var id = UUID()
        var title: String
        /// Minutes of the day.
        var start: Int
        var end: Int
        var isOn = true

        static var suggested: [Block] {
            [
                Block(title: String(localized: "Lunch"), start: 12 * 60 + 30, end: 13 * 60 + 30),
                Block(title: String(localized: "Dinner"), start: 19 * 60, end: 20 * 60, isOn: false),
            ]
        }
    }

    /// The blocks that apply, in day order, with times that make sense.
    var activeBlocks: [Block] {
        blocks
            .filter { $0.isOn && $0.end > $0.start && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.start < $1.start }
    }
}

/// Lays a list of things to do over the free time of a day.
enum DayPlanner {
    struct Item: Identifiable, Equatable {
        var id = UUID()
        var title: String
        var minutes: Int
        var lane: TaskLane = .focus
    }

    struct Placement: Equatable {
        let item: Item.ID
        /// Minutes of the day. An item that does not fit one gap continues in the next.
        let range: ClosedRange<Int>
    }

    struct Result: Equatable {
        var placements: [Placement] = []
        /// Minutes that found no room, per item.
        var leftOver: [Item.ID: Int] = [:]
        /// Free minutes left in the window after everything was placed.
        var freeMinutes = 0
    }

    static let step = DialGeometry.slotMinutes

    /// The stretches of `window` not covered by `busy`, each at least one step long.
    static func gaps(in window: ClosedRange<Int>, busy: [ClosedRange<Int>]) -> [ClosedRange<Int>] {
        var gaps: [ClosedRange<Int>] = []
        var cursor = window.lowerBound
        for range in busy.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            let start = roundedDown(range.lowerBound)
            if start - cursor >= step {
                gaps.append(cursor...start)
            }
            cursor = max(cursor, roundedUp(range.upperBound))
        }
        if window.upperBound - cursor >= step {
            gaps.append(cursor...window.upperBound)
        }
        return gaps
    }

    /// Places items in the order given, each in the earliest free time. Order is priority: what
    /// comes first gets the morning.
    static func schedule(_ items: [Item], window: ClosedRange<Int>, busy: [ClosedRange<Int>]) -> Result {
        var result = Result()
        var free = gaps(in: window, busy: busy)
        for item in items {
            var remaining = max(roundedUp(item.minutes), step)
            while remaining > 0, let gap = free.first {
                let length = min(remaining, gap.upperBound - gap.lowerBound)
                let end = gap.lowerBound + length
                result.placements.append(Placement(item: item.id, range: gap.lowerBound...end))
                remaining -= length
                if gap.upperBound - end >= step {
                    free[0] = end...gap.upperBound
                } else {
                    free.removeFirst()
                }
            }
            if remaining > 0 {
                result.leftOver[item.id] = remaining
            }
        }
        result.freeMinutes = free.reduce(0) { $0 + $1.upperBound - $1.lowerBound }
        return result
    }

    /// The window still open for planning: from the later of now and the start of work, on a step.
    static func window(routine: DayRoutine, nowMinutes: Int?) -> ClosedRange<Int>? {
        let start = max(roundedUp(nowMinutes ?? 0), roundedUp(routine.workStart))
        let end = roundedDown(routine.workEnd)
        return end - start >= step ? start...end : nil
    }

    static func roundedUp(_ minutes: Int) -> Int {
        (minutes + step - 1) / step * step
    }

    static func roundedDown(_ minutes: Int) -> Int {
        minutes / step * step
    }
}

/// The day routine on disk. It lives with the plans, so every Mac sharing the data folder has it.
@Observable
@MainActor
final class RoutineStore {
    var routine: DayRoutine {
        didSet {
            if routine != oldValue {
                file.save(routine)
            }
        }
    }
    /// False until a routine has been saved once; the first planning session asks for it.
    private(set) var isSetUp: Bool
    @ObservationIgnored private var file: JSONFile<DayRoutine>

    init(folder: URL) {
        file = JSONFile(url: folder.appending(path: "routine.json"))
        let saved = file.load()
        isSetUp = saved != nil
        routine = saved ?? DayRoutine()
    }

    func confirm() {
        file.save(routine)
        isSetUp = true
    }

    func reload() {
        if let saved = file.load(), saved != routine {
            routine = saved
            isSetUp = true
        }
    }

    func relocate(to folder: URL) {
        let moved = JSONFile<DayRoutine>(url: folder.appending(path: "routine.json"))
        guard moved.url != file.url else { return }
        file = moved
        if let existing = moved.load(), !isSetUp {
            routine = existing
            isSetUp = true
        } else if isSetUp {
            moved.save(routine)
        }
    }
}
