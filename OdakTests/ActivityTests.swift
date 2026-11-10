import XCTest
@testable import Odak

final class ActivityTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testSlotsAreFiveMinutesWide() {
        XCTAssertEqual(ActivityMath.slot(for: date(10, 0, 4), calendar: calendar), 0)
        XCTAssertEqual(ActivityMath.slot(for: date(10, 9, 5), calendar: calendar), 109)
        XCTAssertEqual(ActivityMath.slot(for: date(10, 23, 59), calendar: calendar), 287)
    }

    func testShortPausesCountAsWorkLongOnesDoNot() {
        XCTAssertEqual(ActivityMath.minutes([]), 0)
        XCTAssertEqual(ActivityMath.minutes([10]), 5)
        // 10 and 13 are two empty slots apart: the pause is bridged.
        XCTAssertEqual(ActivityMath.filled([10, 13]), [10, 11, 12, 13])
        XCTAssertEqual(ActivityMath.minutes([10, 13]), 20)
        // Three empty slots is a real break.
        XCTAssertEqual(ActivityMath.minutes([10, 14]), 10)
    }

    func testNoiseIsIgnored() {
        XCTAssertTrue(ProjectResolver.isNoise(["repo", ".git", "index"]))
        XCTAssertTrue(ProjectResolver.isNoise(["repo", "node_modules", "a", "index.js"]))
        XCTAssertTrue(ProjectResolver.isNoise(["repo", "build", "Odak.app", "Info.plist"]))
        XCTAssertTrue(ProjectResolver.isNoise(["repo", ".DS_Store"]))
        XCTAssertFalse(ProjectResolver.isNoise(["repo", "Sources", "main.swift"]))
    }

    func testFilesResolveToTheirRepository() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "odak-resolver-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        for folder in ["github.com/me/app/.git", "github.com/me/app/Sources/Deep", "local/scratch/notes"] {
            try FileManager.default.createDirectory(at: root.appending(path: folder), withIntermediateDirectories: true)
        }
        var resolver = ProjectResolver(root: root)
        XCTAssertEqual(resolver.project(forPath: root.appending(path: "github.com/me/app/Sources/Deep/a.swift").path), "github.com/me/app")
        XCTAssertEqual(resolver.project(forPath: root.appending(path: "github.com/me/app/README.md").path), "github.com/me/app")
        XCTAssertNil(resolver.project(forPath: root.appending(path: "github.com/me/app/.git/HEAD").path))
        XCTAssertEqual(resolver.project(forPath: root.appending(path: "local/scratch/notes/todo.md").path), "local/scratch")
        XCTAssertNil(resolver.project(forPath: root.appending(path: "loose.txt").path))
        XCTAssertNil(resolver.project(forPath: "/tmp/elsewhere/file.txt"))

        // A linked worktree folds into the repository it belongs to.
        let worktree = root.appending(path: "github.com/me/app-feature/lib")
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        let main = root.appending(path: "github.com/me/app").standardizedFileURL.path
        try "gitdir: \(main)/.git/worktrees/app-feature\n".write(
            to: root.appending(path: "github.com/me/app-feature/.git"), atomically: true, encoding: .utf8
        )
        XCTAssertEqual(resolver.project(forPath: worktree.appending(path: "b.dart").path), "github.com/me/app")
        XCTAssertEqual(GitHistory.repositories(under: root), ["github.com/me/app"])
    }

    @MainActor
    func testStoreRecordsAndReloads() {
        let url = FileManager.default.temporaryDirectory.appending(path: "odak-activity-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ActivityStore(folder: url, device: "a")
        store.record(["a", "b"], at: date(10, 9, 2), calendar: calendar)
        store.record(["a"], at: date(10, 9, 3), calendar: calendar)
        store.record(["a"], at: date(10, 9, 12), calendar: calendar)
        XCTAssertEqual(store.slots(on: date(10, 0), calendar: calendar), ["a": [108, 110], "b": [108]])
        store.flush()

        let reloaded = ActivityStore(folder: url, device: "a")
        XCTAssertEqual(reloaded.slots(on: date(10, 0), calendar: calendar), ["a": [108, 110], "b": [108]])
        XCTAssertTrue(reloaded.slots(on: date(11, 0), calendar: calendar).isEmpty)
    }

    func testWeekReviewCountsParallelProjectsOnce() {
        let days = WeekReview.days(ofWeekContaining: date(10, 12), calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, date(9, 0))

        let review = WeekReview(days: days) { day in
            day == self.date(10, 0) ? ["a": [100, 101, 102], "b": [101, 102, 103, 104]] : (day == self.date(12, 0) ? ["b": [50]] : [:])
        }
        XCTAssertEqual(review.minutesByDay, [0, 25, 0, 5, 0, 0, 0])
        XCTAssertEqual(review.totalMinutes, 30)
        XCTAssertEqual(review.projects.map(\.name), ["b", "a"])
        XCTAssertEqual(review.projects.map(\.minutes), [25, 15])
    }

    func testCommitLogParsing() {
        let output = "abc\u{1F}1794300000\u{1F}Fix the dial\nmalformed line\ndef\u{1F}1794303600\u{1F}Subject with \u{1F} inside\n"
        let commits = GitHistory.parse(output)
        XCTAssertEqual(commits.map(\.id), ["abc", "def"])
        XCTAssertEqual(commits.first?.subject, "Fix the dial")
        XCTAssertEqual(commits.first?.date, Date(timeIntervalSince1970: 1_794_300_000))
        XCTAssertEqual(commits.last?.subject, "Subject with \u{1F} inside")
    }
}
