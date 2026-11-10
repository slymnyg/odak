import SwiftUI

/// The static part of the dial: lane bands, the clock face, hour lines and numerals.
struct DialFace: View {
    let metrics: DialMetrics
    let segment: DaySegment

    var body: some View {
        Canvas { context, _ in
            let center = metrics.center

            for lane in TaskLane.allCases {
                context.stroke(
                    Path(ellipseIn: circle(radius: metrics.laneMid(lane))),
                    with: .color(PlannerPalette.band(lane)),
                    lineWidth: metrics.laneWidth
                )
            }
            context.fill(Path(ellipseIn: circle(radius: metrics.faceRadius)), with: .color(PlannerPalette.face))

            for step in 0..<(DialGeometry.minutesPerTurn / 5) {
                let minutes = Double(step * 5)
                let isHour = step.isMultiple(of: 12)
                let isHalf = step.isMultiple(of: 6)
                let length = metrics.radius * (isHour ? 0.045 : isHalf ? 0.03 : 0.018)
                var tick = Path()
                tick.move(to: DialGeometry.point(forMinutes: minutes, radius: metrics.faceRadius - 5, center: center))
                tick.addLine(to: DialGeometry.point(forMinutes: minutes, radius: metrics.faceRadius - 5 - length, center: center))
                context.stroke(tick, with: .color(PlannerPalette.ink.opacity(isHour ? 0.7 : 0.28)), lineWidth: isHour ? 1.5 : 1)
            }

            let firstHour = segment.startMinutes / 60
            let numberFont = Font.system(size: max(metrics.radius * 0.088, 13), weight: .bold, design: .rounded)
            for hour in firstHour...(firstHour + DaySegment.length / 60) {
                let minutes = Double(hour * 60)
                var line = Path()
                line.move(to: DialGeometry.point(forMinutes: minutes, radius: metrics.faceRadius, center: center))
                line.addLine(to: DialGeometry.point(forMinutes: minutes, radius: metrics.radius, center: center))
                context.stroke(line, with: .color(PlannerPalette.ink.opacity(0.13)), lineWidth: 1)

                context.draw(
                    Text(verbatim: Self.label(forHour: hour)).font(numberFont).foregroundStyle(PlannerPalette.ink),
                    at: DialGeometry.point(forMinutes: minutes, radius: metrics.numberRadius, center: center)
                )
            }

            // Lane names sit in the first minutes of the segment, under any task planned there.
            let labelMinutes = Double(segment.startMinutes) + 16
            for lane in TaskLane.allCases {
                context.drawArcText(
                    lane.localizedName.uppercased(with: .current),
                    font: .system(size: max(metrics.laneWidth * 0.2, 8.5), weight: .semibold),
                    color: PlannerPalette.ink.opacity(0.4),
                    center: center,
                    radius: metrics.laneMid(lane),
                    midAngle: DialGeometry.angle(forMinutes: labelMinutes),
                    maxLength: metrics.laneMid(lane) * 0.27,
                    tracking: 1.2
                )
            }
        }
    }

    /// Follows the reader's clock: 13…24 where the locale uses 24-hour time, otherwise 1…12.
    static func label(forHour hour: Int) -> String {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        if template.contains("a") {
            return "\((hour + 11) % 12 + 1)"
        }
        return "\(hour % 24)"
    }

    private func circle(radius: CGFloat) -> CGRect {
        CGRect(x: metrics.center.x - radius, y: metrics.center.y - radius, width: radius * 2, height: radius * 2)
    }
}
