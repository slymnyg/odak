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
