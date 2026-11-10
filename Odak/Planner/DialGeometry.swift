import CoreGraphics
import Foundation

/// The half of a 12-hour clock face that is on screen.
enum ClockHalf {
    /// 6 → 12, read clockwise up the left side.
    case left
    /// 12 → 6, read clockwise down the right side.
    case right
}

/// A quarter of the day. Each one fills exactly half of a 12-hour clock face.
enum DaySegment: Int, CaseIterable, Identifiable, Hashable {
    case night, morning, afternoon, evening

    static let length = 360

    var id: Int { rawValue }
    var startMinutes: Int { rawValue * Self.length }
    var endMinutes: Int { startMinutes + Self.length }

    var clockHalf: ClockHalf {
        startMinutes % DialGeometry.minutesPerTurn == 0 ? .right : .left
    }

    init(containing date: Date, calendar: Calendar = .current) {
        self = DaySegment(rawValue: calendar.component(.hour, from: date) / 6) ?? .morning
    }
}

enum DialGeometry {
    static let minutesPerTurn = 720
    static let minutesPerDay = 1440
    static let slotMinutes = 30

    /// Radians in screen space (y grows downward): 12 o'clock is -π/2 and angles grow clockwise.
    /// Day minutes work too, since the face repeats every 12 hours.
    static func angle(forMinutes minutes: Double) -> Double {
        minutes / Double(minutesPerTurn) * 2 * .pi - .pi / 2
    }

    /// Minutes past 12 o'clock on the face, in `0..<720`.
    static func minutes(forAngle angle: Double) -> Double {
        var turn = (angle + .pi / 2) / (2 * .pi)
        turn -= turn.rounded(.down)
        return turn * Double(minutesPerTurn)
    }

    static func minutes(at point: CGPoint, center: CGPoint) -> Double {
        minutes(forAngle: atan2(Double(point.y - center.y), Double(point.x - center.x)))
    }

    static func point(forMinutes minutes: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let radians = angle(forMinutes: minutes)
        return CGPoint(x: center.x + radius * CGFloat(cos(radians)), y: center.y + radius * CGFloat(sin(radians)))
    }

    static func snap(_ minutes: Double) -> Int {
        let slots = (minutes / Double(slotMinutes)).rounded()
        return min(max(Int(slots) * slotMinutes, 0), minutesPerTurn)
    }

    /// Minutes into `segment` for a position on the face. Positions on the hidden half clamp to the nearer end.
    static func segmentOffset(forClockMinutes clockMinutes: Double, in segment: DaySegment) -> Double {
        var offset = clockMinutes - Double(segment.startMinutes % minutesPerTurn)
        if offset < 0 { offset += Double(minutesPerTurn) }
        if offset <= Double(DaySegment.length) { return offset }
        return offset > Double(DaySegment.length) * 1.5 ? 0 : Double(DaySegment.length)
    }

    /// The snapped range, in minutes of the day, swept by a drag between two positions on the face.
    static func dragRange(from start: Double, to end: Double, in segment: DaySegment) -> ClosedRange<Int> {
        let anchor = min(snap(segmentOffset(forClockMinutes: start, in: segment)), DaySegment.length)
        let current = min(snap(segmentOffset(forClockMinutes: end, in: segment)), DaySegment.length)
        return (segment.startMinutes + min(anchor, current))...(segment.startMinutes + max(anchor, current))
    }

    static func dayMinutes(for date: Date, on day: Date, calendar: Calendar = .current) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        if date < dayStart { return 0 }
        guard calendar.isDate(date, inSameDayAs: dayStart) else { return minutesPerDay }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func date(forDayMinutes minutes: Int, on day: Date, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        if minutes >= minutesPerDay {
            return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        }
        let clamped = max(minutes, 0)
        return calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: dayStart) ?? dayStart
    }

    /// Minutes of `day` with seconds as a fraction, clamped to the day like `dayMinutes`.
    static func preciseDayMinutes(for date: Date, on day: Date, calendar: Calendar = .current) -> Double {
        let dayStart = calendar.startOfDay(for: day)
        return min(max(date.timeIntervalSince(dayStart) / 60, 0), Double(minutesPerDay))
    }

    /// The part of `start..<end` that falls in the given segment of `day`, in minutes of that day.
    /// Planned tasks sit on whole minutes; pass `precise` for live time that should move smoothly.
    static func visibleMinutes(
        start: Date,
        end: Date,
        segment: DaySegment,
        day: Date,
        precise: Bool = false,
        calendar: Calendar = .current
    ) -> ClosedRange<Double>? {
        func minutes(_ date: Date) -> Double {
            precise ? preciseDayMinutes(for: date, on: day, calendar: calendar) : Double(dayMinutes(for: date, on: day, calendar: calendar))
        }
        let lower = max(minutes(start), Double(segment.startMinutes))
        let upper = min(minutes(end), Double(segment.endMinutes))
        guard upper > lower else { return nil }
        return lower...upper
    }
}

/// Layout of the oversized dial: its centre sits just inside one window edge, so only the
/// segment's half of the face is on screen.
struct DialMetrics {
    let center: CGPoint
    let radius: CGFloat
    let half: ClockHalf

    init(size: CGSize, half: ClockHalf) {
        self.half = half
        radius = max(min(size.height / 2 - 44, size.width * 0.46), 0)
        let inset = radius * 0.17
        center = CGPoint(x: half == .left ? size.width - inset : inset, y: size.height / 2)
    }

    var faceRadius: CGFloat { radius * 0.52 }
    var numberRadius: CGFloat { radius * 0.415 }
    var lanesInner: CGFloat { radius * 0.55 }
    var laneWidth: CGFloat { (radius - lanesInner) / CGFloat(TaskLane.allCases.count) }
    var handLength: CGFloat { radius + 10 }

    /// Width of the window strip the dial needs, including room for the hand's time label.
    var visibleWidth: CGFloat { radius * 1.17 + 96 }

    func laneInner(_ lane: TaskLane) -> CGFloat {
        lanesInner + CGFloat(lane.index) * laneWidth
    }

    func laneMid(_ lane: TaskLane) -> CGFloat {
        laneInner(lane) + laneWidth / 2
    }

    func lane(at point: CGPoint) -> TaskLane? {
        let distance = hypot(point.x - center.x, point.y - center.y)
        guard laneWidth > 0, distance >= lanesInner, distance <= radius else { return nil }
        let index = min(Int((distance - lanesInner) / laneWidth), TaskLane.allCases.count - 1)
        return TaskLane.allCases[index]
    }
}
