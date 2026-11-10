import XCTest
@testable import Odak

final class SessionStatsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func session(daysAgo: Int, minutes: Int = 25, from now: Date) -> Session {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        return Session(start: start, end: start + Double(minutes * 60), plannedMinutes: minutes, actualMinutes: minutes, intention: nil)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testStreakCountsConsecutiveDaysIncludingToday() {
        let sessions = [0, 1, 2, 4].map { session(daysAgo: $0, from: now) }
        XCTAssertEqual(sessions.streak(asOf: now, calendar: calendar), 3)
    }

    func testStreakSurvivesUntilTheEndOfToday() {
        let sessions = [1, 2].map { session(daysAgo: $0, from: now) }
        XCTAssertEqual(sessions.streak(asOf: now, calendar: calendar), 2)
    }

    func testStreakIsZeroAfterAMissedDay() {
        let sessions = [2, 3].map { session(daysAgo: $0, from: now) }
        XCTAssertEqual(sessions.streak(asOf: now, calendar: calendar), 0)
    }

    func testDailyTotalsCoverEachDayOldestFirst() {
        let sessions = [session(daysAgo: 0, minutes: 30, from: now), session(daysAgo: 0, minutes: 15, from: now), session(daysAgo: 6, from: now)]
        let totals = sessions.dailyTotals(days: 7, endingAt: now, calendar: calendar)
        XCTAssertEqual(totals.count, 7)
        XCTAssertEqual(totals.map(\.minutes), [25, 0, 0, 0, 0, 0, 45])
    }
}
