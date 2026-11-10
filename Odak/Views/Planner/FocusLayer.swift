import AppKit
import SwiftUI

/// Focus time on the dial, drawn in the slim channel between the clock face and the lanes:
/// finished sessions as quiet arcs, the running one as a bright arc that fills as it goes, led by
/// a glowing tip. While a session runs, the rest of the dial steps back so only its stretch of
/// time is lit. When one ends, a glint runs the length of its arc and the arc is stamped in place.
struct FocusLayer: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: Date
    let segment: DaySegment
    let metrics: DialMetrics

    @State private var finished: ClosedRange<Double>? = nil
    @State private var glint = 0.0
    @State private var stamp = 0.0
    @State private var tipPulses = false

    private var channelRadius: CGFloat { (metrics.faceRadius + metrics.lanesInner) / 2 }
    private var channelWidth: CGFloat { max((metrics.lanesInner - metrics.faceRadius) * 0.62, 3) }

    var body: some View {
        let live = liveRange
        let past = pastRanges
        ZStack {
            if let live {
                DialVeil(center: metrics.center, radius: metrics.radius + 1, startMinutes: live.window.lowerBound, endMinutes: live.window.upperBound)
                    .fill(OdakPalette.paper.opacity(0.6), style: FillStyle(eoFill: true))
                    .transition(.opacity)
            }

            Canvas { context, _ in
                let radius = channelRadius
                let style = StrokeStyle(lineWidth: channelWidth, lineCap: .round)

                for range in past {
                    context.stroke(arc(range, radius: radius), with: .color(OdakPalette.accent.opacity(0.5)), style: style)
                }
                if let live {
                    context.stroke(arc(live.window, radius: radius), with: .color(OdakPalette.accent.opacity(0.28)), style: style)
                    if let elapsed = live.elapsed {
                        context.stroke(arc(elapsed, radius: radius), with: .color(OdakPalette.accent), style: style)
                    }
                }
            }

            if let tip = live?.elapsed?.upperBound {
                tipGlow(atMinutes: tip)
            }

            if let finished {
                let arc = ChannelArc(center: metrics.center, radius: channelRadius, minutes: finished)
                let style = StrokeStyle(lineWidth: channelWidth, lineCap: .round)
                arc.stroke(OdakPalette.accent, style: StrokeStyle(lineWidth: channelWidth * (1 + 1.4 * stamp), lineCap: .round))
                    .opacity(stamp)
                arc.trim(from: max(glint - 0.22, 0), to: min(glint, 1))
                    .stroke(Color.white.opacity(0.9), style: style)
                    .shadow(color: .white.opacity(0.8), radius: channelWidth)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: live != nil)
        .onChange(of: past.count) { old, new in
            if new > old, !reduceMotion, let last = past.max(by: { $0.upperBound < $1.upperBound }) {
                celebrate(last)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The bright head of the running session, breathing slowly.
    private func tipGlow(atMinutes minutes: Double) -> some View {
        let width = channelWidth
        return Circle()
            .fill(OdakPalette.accent)
            .frame(width: width, height: width)
            .shadow(color: OdakPalette.accent.opacity(tipPulses ? 0.95 : 0.35), radius: tipPulses ? width * 1.5 : width * 0.5)
            .overlay(Circle().fill(Color.white.opacity(tipPulses ? 0.55 : 0.2)).padding(width * 0.22))
            .position(DialGeometry.point(forMinutes: minutes, radius: channelRadius, center: metrics.center))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    tipPulses = true
                }
            }
            .onDisappear { tipPulses = false }
    }

    /// A glint travels the finished arc once, then the arc lands with a soft thump.
    private func celebrate(_ range: ClosedRange<Double>) {
        finished = range
        glint = 0
        stamp = 0
        withAnimation(.easeInOut(duration: 0.9)) {
            glint = 1.22
        } completion: {
            stamp = 1
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            withAnimation(.easeOut(duration: 0.55)) {
                stamp = 0
            } completion: {
                finished = nil
            }
        }
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

/// A stretch of the focus channel, as a shape so it can be trimmed and animated.
private struct ChannelArc: Shape {
    let center: CGPoint
    let radius: CGFloat
    let minutes: ClosedRange<Double>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
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
