import SwiftUI

/// Focus time on the dial, drawn in the slim channel between the clock face and the lanes:
/// finished sessions as quiet arcs, the running one as a bright arc that fills as it goes.
/// While a session runs, the rest of the dial steps back so only its stretch of time is lit.
struct FocusLayer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: Date
    let segment: DaySegment
    let metrics: DialMetrics

    var body: some View {
        let live = liveRange
        ZStack {
            if let live {
                DialVeil(center: metrics.center, radius: metrics.radius + 1, startMinutes: live.window.lowerBound, endMinutes: live.window.upperBound)
                    .fill(OdakPalette.paper.opacity(0.6), style: FillStyle(eoFill: true))
                    .transition(.opacity)
            }

            Canvas { context, _ in
                let radius = (metrics.faceRadius + metrics.lanesInner) / 2
                let width = max((metrics.lanesInner - metrics.faceRadius) * 0.62, 3)
                let style = StrokeStyle(lineWidth: width, lineCap: .round)

                for range in pastRanges {
                    context.stroke(arc(range, radius: radius), with: .color(OdakPalette.accent.opacity(0.5)), style: style)
                }
                if let live {
                    context.stroke(arc(live.window, radius: radius), with: .color(OdakPalette.accent.opacity(0.28)), style: style)
                    if let elapsed = live.elapsed {
                        context.stroke(arc(elapsed, radius: radius), with: .color(OdakPalette.accent), style: style)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: live != nil)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Live: Equatable {
        /// The visible part of the session, in minutes of the day.
        let window: ClosedRange<Double>
        /// The visible part that is already behind us.
        let elapsed: ClosedRange<Double>?
    }

    /// The running focus session, if it shows on this day and segment. While paused its end is
    /// not fixed yet, so the window is measured from now and slides along.
    private var liveRange: Live? {
        let timer = model.timer
        let now = Date.now
        guard timer.isFocusing, Calendar.current.isDate(now, inSameDayAs: day) else { return nil }
        let start = now.addingTimeInterval(-(timer.duration - timer.remaining))
        let end = now.addingTimeInterval(timer.remaining)
        guard let window = DialGeometry.visibleMinutes(start: start, end: end, segment: segment, day: day, precise: true) else { return nil }
        return Live(
            window: window,
            elapsed: DialGeometry.visibleMinutes(start: start, end: now, segment: segment, day: day, precise: true)
        )
    }

    private var pastRanges: [ClosedRange<Double>] {
        model.history.sessions.sessions(on: day).compactMap {
            DialGeometry.visibleMinutes(start: $0.start, end: $0.end, segment: segment, day: day, precise: true)
        }
    }

    private func arc(_ minutes: ClosedRange<Double>, radius: CGFloat) -> Path {
        var path = Path()
        path.addArc(
            center: metrics.center,
            radius: radius,
            startAngle: .radians(DialGeometry.angle(forMinutes: minutes.lowerBound)),
            endAngle: .radians(DialGeometry.angle(forMinutes: minutes.upperBound)),
            clockwise: false
        )
        return path
    }
}

/// The whole dial except one wedge of time. Filled even-odd, it dims everything outside the wedge.
private struct DialVeil: Shape {
    var center: CGPoint
    var radius: CGFloat
    var startMinutes: Double
    var endMinutes: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startMinutes, endMinutes) }
        set {
            startMinutes = newValue.first
            endMinutes = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .radians(DialGeometry.angle(forMinutes: startMinutes)),
            endAngle: .radians(DialGeometry.angle(forMinutes: endMinutes)),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
