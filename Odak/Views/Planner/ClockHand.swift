import SwiftUI

/// The "now" hand: a hairline from the hub through every lane, with the time at its tip.
/// It sweeps in from the start of the segment when the dial appears.
struct ClockHand: View {
    let day: Date
    let segment: DaySegment
    let metrics: DialMetrics
    /// Minutes left in the running focus session; the hand turns green and counts them down.
    var focusMinutesLeft: Int? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasSwept = false

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = timeline.date
            let isShown = Calendar.current.isDate(now, inSameDayAs: day) && DaySegment(containing: now) == segment
            let minutes = hasSwept || reduceMotion ? Self.dayMinutes(for: now) : Double(segment.startMinutes)
            HandCanvas(minutes: minutes, label: isShown ? now : nil, metrics: metrics, focusMinutesLeft: focusMinutesLeft)
                .animation(.spring(duration: 1.0, bounce: 0.22), value: minutes)
        }
        .onAppear { hasSwept = true }
    }

    private static func dayMinutes(for date: Date) -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }
}

private struct HandCanvas: View, Animatable {
    var minutes: Double
    /// The time to print at the tip; `nil` hides the hand and leaves only the hub.
    let label: Date?
    let metrics: DialMetrics
    let focusMinutesLeft: Int?

    var animatableData: Double {
        get { minutes }
        set { minutes = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            let center = metrics.center
            context.fill(Path(ellipseIn: dot(at: center, radius: 5)), with: .color(OdakPalette.ink))
            context.fill(Path(ellipseIn: dot(at: center, radius: 1.8)), with: .color(OdakPalette.face))
            guard let label else { return }
            let tint = focusMinutesLeft == nil ? OdakPalette.ink : OdakPalette.accent
            let time = label.formatted(.dateTime.hour().minute())
            let caption = focusMinutesLeft.map { time + " · " + String(localized: "\($0) min") } ?? time

            var hand = Path()
            hand.move(to: DialGeometry.point(forMinutes: minutes, radius: 5, center: center))
            hand.addLine(to: DialGeometry.point(forMinutes: minutes, radius: metrics.handLength, center: center))
            context.stroke(hand, with: .color(tint), style: StrokeStyle(lineWidth: focusMinutesLeft == nil ? 1.5 : 2, lineCap: .round))

            let text = context.resolve(
                Text(verbatim: caption)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(focusMinutesLeft == nil ? OdakPalette.paper : OdakPalette.onTask)
            )
            let size = text.measure(in: CGSize(width: 120, height: 40))
            let anchor = DialGeometry.point(forMinutes: minutes, radius: metrics.handLength + size.width / 2 + 4, center: center)
            let pill = CGRect(x: anchor.x - size.width / 2 - 6, y: anchor.y - size.height / 2 - 3, width: size.width + 12, height: size.height + 6)
            context.fill(Path(roundedRect: pill, cornerRadius: pill.height / 2), with: .color(tint))
            context.draw(text, at: anchor, anchor: .center)
        }
    }

    private func dot(at point: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
    }
}
