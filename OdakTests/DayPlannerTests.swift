import XCTest
@testable import Odak

final class DayPlannerTests: XCTestCase {
    private func item(_ title: String, _ minutes: Int) -> DayPlanner.Item {
        DayPlanner.Item(title: title, minutes: minutes)
    }

    func testGapsSkipBusyTimeAndSnapToSlots() {
        let gaps = DayPlanner.gaps(in: 540...1080, busy: [750...810, 615...640])
        XCTAssertEqual(gaps, [540...600, 660...750, 810...1080])
    }

    func testItemsTakeTheEarliestFreeTimeInOrder() {
        let a = item("a", 90), b = item("b", 60)
        let result = DayPlanner.schedule([a, b], window: 540...1080, busy: [750...810])
        XCTAssertEqual(result.placements, [
            .init(item: a.id, range: 540...630),
            .init(item: b.id, range: 630...690),
        ])
        XCTAssertTrue(result.leftOver.isEmpty)
        XCTAssertEqual(result.freeMinutes, 60 + 270)
    }

    func testALongItemContinuesAfterABreak() {
        let a = item("a", 240)
        let result = DayPlanner.schedule([a], window: 540...1080, busy: [750...810])
        XCTAssertEqual(result.placements.map(\.range), [540...750, 810...840])
    }

    func testWhatDoesNotFitIsReported() {
        let a = item("a", 120), b = item("b", 90)
        let result = DayPlanner.schedule([a, b], window: 960...1080, busy: [])
        XCTAssertEqual(result.placements, [.init(item: a.id, range: 960...1080)])
        XCTAssertEqual(result.leftOver, [b.id: 90])
        XCTAssertEqual(result.freeMinutes, 0)
    }

    func testWindowStartsAtTheLaterOfNowAndWorkStart() {
        let routine = DayRoutine()
        XCTAssertEqual(DayPlanner.window(routine: routine, nowMinutes: 7 * 60), 540...1080)
        XCTAssertEqual(DayPlanner.window(routine: routine, nowMinutes: 10 * 60 + 10), 630...1080)
        XCTAssertNil(DayPlanner.window(routine: routine, nowMinutes: 17 * 60 + 45))
    }

    func testOnlyUsableBlocksAreActive() {
        var routine = DayRoutine()
        routine.blocks = [
            .init(title: "Dinner", start: 1140, end: 1200),
            .init(title: "Off", start: 600, end: 630, isOn: false),
            .init(title: "Backwards", start: 700, end: 650),
            .init(title: " ", start: 800, end: 830),
            .init(title: "Lunch", start: 750, end: 810),
        ]
        XCTAssertEqual(routine.activeBlocks.map(\.title), ["Lunch", "Dinner"])
    }

    @MainActor
    func testApplyingThePlanWritesBreaksAndTasksOnce() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "odak-day-\(UUID().uuidString)", directoryHint: .isDirectory)
        // The test host shares the app's preferences; leave the "planned today" mark as it was.
        let planned = Preferences.lastPlannedDay
        defer {
            try? FileManager.default.removeItem(at: root)
            Preferences.lastPlannedDay = planned
        }
        let model = AppModel(storage: Storage(root: root, device: "t"))
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        let today = calendar.startOfDay(for: now)
        model.routine.routine.blocks = [.init(title: "Lunch", start: 750, end: 810)]

        let a = DayPlanner.Item(title: "Write", minutes: 240)
        let outline = DayOutline(routine: model.routine.routine, existing: [], items: [a], day: today, now: now)
        XCTAssertEqual(outline.entries.map(\.kind), [.planned, .routine, .planned, .free])
        model.applyDayPlan(items: [a], placements: outline.result.placements, now: now)
        XCTAssertEqual(model.plans.tasks(on: today).map(\.title), ["Write", "Lunch", "Write"])
        XCTAssertEqual(model.plans.tasks(on: today).map(\.lane), [.focus, .personal, .focus])

        // Planning again keeps the break single and plans around what is there.
        let b = DayPlanner.Item(title: "Review", minutes: 60)
        let again = DayOutline(routine: model.routine.routine, existing: model.plans.tasks(on: today), items: [b], day: today, now: now)
        model.applyDayPlan(items: [b], placements: again.result.placements, now: now)
        let titles = model.plans.tasks(on: today).map(\.title)
        XCTAssertEqual(titles.filter { $0 == "Lunch" }.count, 1)
        XCTAssertEqual(titles, ["Write", "Lunch", "Write", "Review"])
    }
}

@MainActor
final class PostponeTests: XCTestCase {
    private var root: URL!
    private var model: AppModel!
    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appending(path: "odak-postpone-\(UUID().uuidString)", directoryHint: .isDirectory)
        model = AppModel(storage: Storage(root: root, device: "t"))
        model.routine.routine.blocks = []
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.date(byAdding: .day, value: day, to: today)!)!
    }

    @discardableResult
    private func add(_ title: String, _ start: Date, _ end: Date, _ lane: TaskLane = .focus) -> PlannedTask {
        let task = PlannedTask(title: title, note: "", start: start, end: end, lane: lane)
        model.plans.save(task)
        return task
    }

    private func plan(day: Int = 0) -> [String] {
        model.plans.tasks(on: at(0, day: day)).map {
            "\($0.title) \(calendar.component(.hour, from: $0.start)):\(String(format: "%02d", calendar.component(.minute, from: $0.start)))"
        }
    }

    func testPushingBackTakesLaterFocusWorkAlongAndLeavesMeetingsAlone() {
        let a = add("a", at(9), at(10))
        add("b", at(10), at(11, 30))
        add("meet", at(11, 30), at(12), .meeting)
        add("c", at(12), at(13))
        add("d", at(15), at(16))
        XCTAssertTrue(model.postpone(a, .later(minutes: 30), now: at(8)))
        // b follows a and no longer fits before the meeting, so its last half hour continues
        // after it; c is pushed by that; d was clear of it all and stays.
        XCTAssertEqual(plan(), ["a 9:30", "b 10:30", "meet 11:30", "b 12:00", "c 12:30", "d 15:00"])
    }

    func testPushingBackAMissedTaskStartsFromNow() {
        let a = add("a", at(9), at(10))
        XCTAssertTrue(model.postpone(a, .later(minutes: 30), now: at(13, 10)))
        XCTAssertEqual(plan(), ["a 13:30"])
        XCTAssertEqual(model.plans.task(withID: a.id)?.end, at(14, 30))
    }

    func testNextFreeTimeGoesAroundWhatIsPlanned() {
        let a = add("a", at(9), at(10))
        add("meet", at(14), at(15), .meeting)
        XCTAssertTrue(model.postpone(a, .nextFree, now: at(13, 40)))
        XCTAssertEqual(plan(), ["meet 14:00", "a 15:00"])
    }

    func testNoRoomChangesNothing() {
        let a = add("a", at(9), at(11))
        XCTAssertFalse(model.postpone(a, .nextFree, now: at(17, 10)))
        XCTAssertEqual(plan(), ["a 9:00"])
        XCTAssertEqual(model.planNotice?.isWarning, true)
    }

    func testTomorrowTakesTheFirstFreeTimeOfTheNextDay() {
        let a = add("a", at(15), at(16))
        add("early", at(9, day: 1), at(10, day: 1))
        XCTAssertTrue(model.postpone(a, .tomorrow, now: at(16, 30)))
        XCTAssertTrue(plan().isEmpty)
        XCTAssertEqual(plan(day: 1), ["early 9:00", "a 10:00"])
        XCTAssertEqual(model.plans.allTasks.count, 2)
    }
}
