import XCTest
@testable import Odak

final class DialGeometryTests: XCTestCase {
    private let accuracy = 1e-9
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: hour, minute: minute))!
    }

    func testTwelveIsAtTopAndAnglesRunClockwise() {
        XCTAssertEqual(DialGeometry.angle(forMinutes: 0), -.pi / 2, accuracy: accuracy)
        XCTAssertEqual(DialGeometry.angle(forMinutes: 180), 0, accuracy: accuracy)
        XCTAssertEqual(DialGeometry.angle(forMinutes: 360), .pi / 2, accuracy: accuracy)
    }

    func testMinutesFromPoints() {
        let center = CGPoint(x: 100, y: 100)
        XCTAssertEqual(DialGeometry.minutes(at: CGPoint(x: 100, y: 0), center: center), 0, accuracy: accuracy)
        XCTAssertEqual(DialGeometry.minutes(at: CGPoint(x: 200, y: 100), center: center), 180, accuracy: accuracy)
        XCTAssertEqual(DialGeometry.minutes(at: CGPoint(x: 100, y: 200), center: center), 360, accuracy: accuracy)
        XCTAssertEqual(DialGeometry.minutes(at: CGPoint(x: 0, y: 100), center: center), 540, accuracy: accuracy)
    }

    func testAngleRoundTrip() {
        for minutes in stride(from: 0.0, to: 720, by: 37.5) {
            XCTAssertEqual(DialGeometry.minutes(forAngle: DialGeometry.angle(forMinutes: minutes)), minutes, accuracy: 1e-6)
        }
    }

    func testSnapsToHalfHours() {
        XCTAssertEqual(DialGeometry.snap(44), 30)
        XCTAssertEqual(DialGeometry.snap(46), 60)
        XCTAssertEqual(DialGeometry.snap(719), 720)
        XCTAssertEqual(DialGeometry.snap(-5), 0)
    }

    func testSegmentsSplitTheDayIntoClockHalves() {
        XCTAssertEqual(DaySegment(containing: date(5, 59), calendar: calendar), .night)
        XCTAssertEqual(DaySegment(containing: date(6), calendar: calendar), .morning)
        XCTAssertEqual(DaySegment(containing: date(14, 20), calendar: calendar), .afternoon)
        XCTAssertEqual(DaySegment(containing: date(23, 59), calendar: calendar), .evening)
        XCTAssertEqual(DaySegment.morning.clockHalf, .left)
        XCTAssertEqual(DaySegment.afternoon.clockHalf, .right)
        XCTAssertEqual(DaySegment.evening.startMinutes, 1080)
    }

    func testDragRangeStaysInsideTheSegment() {
        // Morning: 6 o'clock on the face is 360 clock minutes.
        XCTAssertEqual(DialGeometry.dragRange(from: 455, to: 530, in: .morning), 450...540)
        XCTAssertEqual(DialGeometry.dragRange(from: 530, to: 455, in: .morning), 450...540)
        // Afternoon shares the face with night; the same spot maps to a different time of day.
        XCTAssertEqual(DialGeometry.dragRange(from: 95, to: 170, in: .afternoon), 810...900)
        XCTAssertEqual(DialGeometry.dragRange(from: 95, to: 170, in: .night), 90...180)
        // Dragging onto the hidden half clamps to the nearer end of the segment.
        XCTAssertEqual(DialGeometry.dragRange(from: 660, to: 40, in: .morning), 660...720)
        XCTAssertEqual(DialGeometry.dragRange(from: 400, to: 300, in: .morning), 360...390)
    }

    func testDayMinutesAndDatesRoundTrip() {
        let day = date(0)
        XCTAssertEqual(DialGeometry.dayMinutes(for: date(9, 30), on: day, calendar: calendar), 570)
        XCTAssertEqual(DialGeometry.date(forDayMinutes: 570, on: day, calendar: calendar), date(9, 30))
        XCTAssertEqual(DialGeometry.date(forDayMinutes: 1440, on: day, calendar: calendar), date(24))
        XCTAssertEqual(DialGeometry.dayMinutes(for: date(24, 30), on: day, calendar: calendar), 1440)
    }

    func testTaskIsClippedToTheVisibleSegment() {
        let day = date(0)
        let start = date(11), end = date(13)
        XCTAssertEqual(DialGeometry.visibleMinutes(start: start, end: end, segment: .morning, day: day, calendar: calendar), 660...720)
        XCTAssertEqual(DialGeometry.visibleMinutes(start: start, end: end, segment: .afternoon, day: day, calendar: calendar), 720...780)
        XCTAssertNil(DialGeometry.visibleMinutes(start: date(8), end: date(9), segment: .afternoon, day: day, calendar: calendar))
    }

    func testLiveTimeKeepsItsSeconds() {
        let day = date(0)
        let start = date(13, 30).addingTimeInterval(30), end = date(14, 0).addingTimeInterval(15)
        let whole = DialGeometry.visibleMinutes(start: start, end: end, segment: .afternoon, day: day, calendar: calendar)
        let precise = DialGeometry.visibleMinutes(start: start, end: end, segment: .afternoon, day: day, precise: true, calendar: calendar)
        XCTAssertEqual(whole, 810...840)
        XCTAssertEqual(precise?.lowerBound ?? 0, 810.5, accuracy: 1e-6)
        XCTAssertEqual(precise?.upperBound ?? 0, 840.25, accuracy: 1e-6)
        XCTAssertNil(DialGeometry.visibleMinutes(start: start, end: end, segment: .morning, day: day, precise: true, calendar: calendar))
    }

    func testLanesRunOutwardFromTheFace() {
        let metrics = DialMetrics(size: CGSize(width: 1000, height: 688), half: .left)
        XCTAssertEqual(metrics.radius, 300, accuracy: accuracy)
        XCTAssertEqual(metrics.center.x, 949, accuracy: 1e-6)
        func point(_ distance: CGFloat) -> CGPoint { CGPoint(x: metrics.center.x - distance, y: metrics.center.y) }
        XCTAssertNil(metrics.lane(at: point(150)))
        XCTAssertEqual(metrics.lane(at: point(170)), .focus)
        XCTAssertEqual(metrics.lane(at: point(240)), .meeting)
        XCTAssertEqual(metrics.lane(at: point(299)), .personal)
        XCTAssertNil(metrics.lane(at: point(305)))
    }

    func testPlansWithoutALaneStillDecode() throws {
        let json = #"[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Yaz","note":"","start":0,"end":1800,"color":"green"}]"#
        let tasks = try JSONDecoder().decode([PlannedTask].self, from: Data(json.utf8))
        XCTAssertEqual(tasks.first?.lane, .focus)
    }
}
