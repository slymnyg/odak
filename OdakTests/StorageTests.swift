import XCTest
@testable import Odak

@MainActor
final class StorageTests: XCTestCase {
    private var root: URL!
    private let calendar = Calendar.current

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appending(path: "odak-storage-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func task(_ title: String, day: Int, hour: Int = 9) -> PlannedTask {
        PlannedTask(title: title, note: "", start: date(day, hour), end: date(day, hour + 1), lane: .focus)
    }

    private func folder(_ name: String) -> URL {
        root.appending(path: name, directoryHint: .isDirectory)
    }

    private func names(in folder: URL) -> [String] {
        Storage.jsonFiles(in: folder).map(\.lastPathComponent)
    }

    func testPlansAreOneFilePerDay() {
        let store = PlanStore(folder: folder("plans"))
        store.save(task("a", day: 10))
        store.save(task("b", day: 10, hour: 14))
        store.save(task("c", day: 11))
        XCTAssertEqual(names(in: folder("plans")), ["2026-11-10.json", "2026-11-11.json"])
        XCTAssertEqual(PlanStore(folder: folder("plans")).tasks(on: date(10, 0)).map(\.title), ["a", "b"])
    }

    func testMovingATaskRewritesBothDays() {
        let store = PlanStore(folder: folder("plans"))
        var moved = task("a", day: 10)
        store.save(moved)
        moved.start = date(12, 9)
        moved.end = date(12, 10)
        store.save(moved)
        let reloaded = PlanStore(folder: folder("plans"))
        XCTAssertTrue(reloaded.tasks(on: date(10, 0)).isEmpty)
        XCTAssertEqual(reloaded.tasks(on: date(12, 0)).map(\.title), ["a"])
        XCTAssertEqual(reloaded.allTasks.count, 1)
    }

    func testDeletingTheLastTaskLeavesAnEmptyDayFile() {
        let store = PlanStore(folder: folder("plans"))
        let only = task("a", day: 10)
        store.save(only)
        store.delete(only)
        XCTAssertEqual(names(in: folder("plans")), ["2026-11-10.json"])
        XCTAssertTrue(PlanStore(folder: folder("plans")).allTasks.isEmpty)
    }

    func testSavingKeepsWhatAnotherMacWroteMeanwhile() {
        let here = PlanStore(folder: folder("plans"))
        let there = PlanStore(folder: folder("plans"))
        there.save(task("theirs", day: 10))
        here.save(task("mine", day: 10, hour: 14))
        XCTAssertEqual(PlanStore(folder: folder("plans")).tasks(on: date(10, 0)).map(\.title), ["theirs", "mine"])
    }

    func testReloadPicksUpOutsideChanges() {
        let here = PlanStore(folder: folder("plans"))
        PlanStore(folder: folder("plans")).save(task("theirs", day: 10))
        XCTAssertTrue(here.allTasks.isEmpty)
        here.reload()
        XCTAssertEqual(here.allTasks.map(\.title), ["theirs"])
    }

    func testConflictCopiesAreIgnored() throws {
        let store = PlanStore(folder: folder("plans"))
        store.save(task("a", day: 10))
        try FileManager.default.copyItem(
            at: folder("plans").appending(path: "2026-11-10.json"),
            to: folder("plans").appending(path: "2026-11-10 2.json")
        )
        XCTAssertEqual(PlanStore(folder: folder("plans")).allTasks.count, 1)
        XCTAssertFalse(PlanFiles.isDayFile(URL(fileURLWithPath: "/x/2026-11-10 2.json")))
    }

    func testRelocatingPlansMergesBothSides() {
        let local = PlanStore(folder: folder("local"))
        var shared = task("shared", day: 10)
        local.save(shared)
        local.save(task("mine", day: 11))
        let remote = PlanStore(folder: folder("cloud"))
        shared.title = "older copy"
        remote.save(shared)
        remote.save(task("theirs", day: 12))

        local.relocate(to: folder("cloud"))
        let merged = PlanStore(folder: folder("cloud"))
        XCTAssertEqual(merged.allTasks.map(\.title).sorted(), ["mine", "shared", "theirs"])
        // The folder left behind still holds its data.
        XCTAssertEqual(PlanStore(folder: folder("local")).allTasks.count, 2)
    }

    private func session(hour: Int) -> Session {
        Session(start: date(10, hour), end: date(10, hour + 1), plannedMinutes: 60, actualMinutes: 60, intention: nil)
    }

    func testSessionsFromEveryMacAreMerged() {
        let work = SessionStore(folder: folder("sessions"), device: "work")
        let home = SessionStore(folder: folder("sessions"), device: "home")
        work.record(session(hour: 14))
        home.record(session(hour: 9))
        XCTAssertEqual(names(in: folder("sessions")), ["home.json", "work.json"])
        XCTAssertEqual(work.sessions.count, 1)
        work.reload()
        XCTAssertEqual(work.sessions.map { calendar.component(.hour, from: $0.start) }, [9, 14])

        // Writing again must not copy the other Mac's sessions into this Mac's file.
        work.record(session(hour: 16))
        XCTAssertEqual(SessionStore(folder: folder("solo"), device: "x").sessions.count, 0)
        XCTAssertEqual((JSONFile<[Session]>(url: folder("sessions").appending(path: "work.json")).load() ?? []).count, 2)
    }

    func testRelocatingSessionsKeepsBothHistories() {
        let local = SessionStore(folder: folder("local"), device: "work")
        local.record(session(hour: 9))
        SessionStore(folder: folder("cloud"), device: "home").record(session(hour: 20))
        local.relocate(to: folder("cloud"))
        XCTAssertEqual(local.sessions.count, 2)
        XCTAssertEqual(SessionStore(folder: folder("cloud"), device: "work").sessions.count, 2)
    }

    func testActivityFromEveryMacIsLaidOverOneAnother() {
        let work = ActivityStore(folder: folder("activity"), device: "work")
        let home = ActivityStore(folder: folder("activity"), device: "home")
        work.record(["app"], at: date(10, 9), calendar: calendar)
        home.record(["app", "site"], at: date(10, 20), calendar: calendar)
        work.flush()
        home.flush()
        work.reload()
        XCTAssertEqual(work.slots(on: date(10, 0), calendar: calendar), ["app": [108, 240], "site": [240]])
        // Recording after a reload keeps the other Mac's slots.
        work.record(["app"], at: date(10, 10), calendar: calendar)
        XCTAssertEqual(work.slots(on: date(10, 0), calendar: calendar)["app"], [108, 120, 240])
    }

    func testLegacyFilesAreAdoptedOnceAndKept() {
        let storage = Storage(root: root, device: "mac")
        JSONFile<[PlannedTask]>(url: root.appending(path: "plans.json")).save([task("old", day: 10)])
        JSONFile<[Session]>(url: root.appending(path: "sessions.json")).save([session(hour: 9)])
        JSONFile<[String: [String: [Int]]]>(url: root.appending(path: "activity.json")).save(["2026-11-10": ["app": [1, 2]]])

        storage.adoptLegacyFiles()
        XCTAssertEqual(PlanStore(folder: storage.plans).allTasks.map(\.title), ["old"])
        XCTAssertEqual(SessionStore(folder: storage.sessions, device: "mac").sessions.count, 1)
        XCTAssertEqual(ActivityStore(folder: storage.activity, device: "mac").days["2026-11-10"]?["app"], [1, 2])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "plans.json").path))

        // A second run must not bring back what was deleted since.
        let store = PlanStore(folder: storage.plans)
        store.delete(store.allTasks[0])
        storage.adoptLegacyFiles()
        XCTAssertTrue(PlanStore(folder: storage.plans).allTasks.isEmpty)
    }

    func testUnreachableFolderIsNotCreated() {
        let missing = root.appending(path: "not-mounted/Odak", directoryHint: .isDirectory)
        XCTAssertFalse(Storage.isReachable(missing))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        XCTAssertTrue(Storage.isReachable(folder("fresh")))
        XCTAssertEqual(Storage.fileSafe("Süleyman’ın MacBook Pro"), "Suleyman-in-MacBook-Pro")
    }
}

@MainActor
final class GoalStoreTests: XCTestCase {
    private var root: URL!
    private let calendar = Calendar.current

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appending(path: "odak-goals-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testGoalsAreOneFileEachAndSurviveAReload() {
        let store = GoalStore(folder: root)
        XCTAssertNil(store.add("   "))
        store.add("Ship the update feature")
        store.add(" Write release notes ")
        XCTAssertEqual(Storage.jsonFiles(in: root).count, 2)
        XCTAssertEqual(GoalStore(folder: root).goals.map(\.title), ["Ship the update feature", "Write release notes"])
    }

    func testDoneGoalsStayForTheWeekThenLeave() throws {
        let store = GoalStore(folder: root)
        let a = try XCTUnwrap(store.add("a"))
        let b = try XCTUnwrap(store.add("b"))
        let now = Date.now
        store.setDone(true, for: a.id, at: now)
        XCTAssertEqual(store.visible(inWeekOf: now).map(\.title), ["b", "a"])

        let nextWeek = try XCTUnwrap(calendar.date(byAdding: .day, value: 8, to: now))
        XCTAssertEqual(store.visible(inWeekOf: nextWeek).map(\.title), ["b"])

        store.setDone(false, for: a.id)
        XCTAssertEqual(GoalStore(folder: root).visible(inWeekOf: nextWeek).map(\.title), ["a", "b"])
        XCTAssertEqual(b.isDone, false)
    }

    func testRemovingAGoalRemovesItsFile() throws {
        let store = GoalStore(folder: root)
        let a = try XCTUnwrap(store.add("a"))
        store.add("b")
        store.remove(a.id)
        XCTAssertEqual(GoalStore(folder: root).goals.map(\.title), ["b"])
    }

    func testAnotherMacsGoalsAppearOnReload() {
        let here = GoalStore(folder: root)
        GoalStore(folder: root).add("theirs")
        here.add("mine")
        here.reload()
        XCTAssertEqual(Set(here.goals.map(\.title)), ["mine", "theirs"])
    }

    func testFittingIntoTodayUsesFreeTimeOrRefuses() throws {
        let planned = Preferences.lastPlannedDay
        defer { Preferences.lastPlannedDay = planned }
        let model = AppModel(storage: Storage(root: root, device: "t"))
        let now = try XCTUnwrap(calendar.date(bySettingHour: 16, minute: 0, second: 0, of: .now))
        model.routine.routine.blocks = []
        XCTAssertTrue(model.fitIntoToday(title: "a", minutes: 60, now: now))
        XCTAssertFalse(model.fitIntoToday(title: "b", minutes: 120, now: now))
        let tasks = model.plans.tasks(on: now)
        XCTAssertEqual(tasks.map(\.title), ["a"])
        XCTAssertEqual(calendar.component(.hour, from: tasks[0].start), 16)
    }
}
