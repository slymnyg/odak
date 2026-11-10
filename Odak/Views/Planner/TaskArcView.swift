import SwiftUI

struct TaskArcView: View {
    let task: PlannedTask
    /// Visible part of the task, in minutes of the day.
    let minutes: ClosedRange<Double>
    let isSelected: Bool
    let metrics: DialMetrics
    /// Position among the visible tasks; later ones sweep in a beat after earlier ones.
    var order = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrawn = false
    @State private var isHovered = false

    var body: some View {
        let gap = metrics.laneWidth * 0.09
        let corner = metrics.laneWidth * 0.26
        let slice = LaneArc(
            center: metrics.center,
            innerRadius: metrics.laneInner(task.lane) + gap,
            outerRadius: metrics.laneInner(task.lane) + metrics.laneWidth - gap,
            startMinutes: minutes.lowerBound,
            endMinutes: isDrawn ? minutes.upperBound : minutes.lowerBound
        )
        var core = slice
        core.inset = corner + 1
        let rounded = StrokeStyle(lineWidth: corner * 2, lineJoin: .round)

        return ZStack {
            if isSelected {
                core.stroke(PlannerPalette.ink, style: StrokeStyle(lineWidth: corner * 2 + 5, lineJoin: .round))
            }
            Group {
                core.fill(task.lane.tint)
                core.stroke(task.lane.tint, style: rounded)
            }
            .brightness(isHovered ? 0.06 : 0)
            .shadow(color: task.lane.tint.opacity(isHovered ? 0.45 : 0), radius: 9, y: 2)
            Canvas { context, _ in
                let radius = metrics.laneMid(task.lane)
                let span = DialGeometry.angle(forMinutes: minutes.upperBound) - DialGeometry.angle(forMinutes: minutes.lowerBound)
                let room = radius * CGFloat(span) - corner * 2 - 8
                guard room > 22 else { return }
                context.drawArcText(
                    task.title,
                    font: .system(size: max(metrics.laneWidth * 0.27, 10.5), weight: .semibold),
                    color: PlannerPalette.onTask,
                    center: metrics.center,
                    radius: radius,
                    midAngle: DialGeometry.angle(forMinutes: (minutes.lowerBound + minutes.upperBound) / 2),
                    maxLength: room
                )
            }
            .opacity(isDrawn ? 1 : 0)
            .allowsHitTesting(false)
        }
        .contentShape(slice)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .onAppear {
            guard !reduceMotion else {
                isDrawn = true
                return
            }
            withAnimation(.spring(duration: 0.65, bounce: 0.18).delay(0.12 + Double(order) * 0.06)) {
                isDrawn = true
            }
        }
        .help(Text(verbatim: "\(task.title) · \(task.timeRangeText)"))
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(task.title), \(task.timeRangeText)"))
    }
}
