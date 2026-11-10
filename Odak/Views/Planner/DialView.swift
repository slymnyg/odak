import AppKit
import SwiftUI

struct DialView: View {
    let day: Date
    let segment: DaySegment
    let metrics: DialMetrics
    let tasks: [PlannedTask]
    @Binding var selectedTaskID: PlannedTask.ID?
    let onCreate: (ClosedRange<Int>, TaskLane) -> Void
    let onEdit: (PlannedTask) -> Void
    let onDelete: (PlannedTask) -> Void

    @State private var preview: Preview? = nil

    private struct Preview {
        let lane: TaskLane
        let minutes: ClosedRange<Int>
    }

    private struct TaskSlot: Hashable {
        let day: Date
        let task: PlannedTask.ID
    }

    private struct VisibleArc: Identifiable {
        let task: PlannedTask
        let minutes: ClosedRange<Double>

        var id: PlannedTask.ID { task.id }
    }

    var body: some View {
        ZStack {
            DialFace(metrics: metrics, segment: segment)
                .contentShape(Circle().path(in: dialBounds))
                .onTapGesture { selectedTaskID = nil }

            ForEach(Array(visibleArcs.enumerated()), id: \.element.id) { order, arc in
                TaskArcView(task: arc.task, minutes: arc.minutes, isSelected: arc.id == selectedTaskID, metrics: metrics, order: order)
                    // A new day draws its tasks afresh.
                    .id(TaskSlot(day: day, task: arc.id))
                    .onTapGesture(count: 2) { onEdit(arc.task) }
                    .onTapGesture { selectedTaskID = arc.id }
                    .contextMenu {
                        Button("Edit…") { onEdit(arc.task) }
                        Button("Delete", role: .destructive) { onDelete(arc.task) }
                    }
            }

            if let preview {
                LaneArc(
                    center: metrics.center,
                    innerRadius: metrics.laneInner(preview.lane) + metrics.laneWidth * 0.09,
                    outerRadius: metrics.laneInner(preview.lane) + metrics.laneWidth * 0.91,
                    startMinutes: Double(preview.minutes.lowerBound),
                    endMinutes: Double(preview.minutes.upperBound)
                )
                .fill(preview.lane.tint.opacity(0.4))
                .allowsHitTesting(false)
            }

            FocusLayer(day: day, segment: segment, metrics: metrics)

            LiveHand(day: day, segment: segment, metrics: metrics)
                .allowsHitTesting(false)
        }
        .simultaneousGesture(createGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Day dial"))
    }

    private var dialBounds: CGRect {
        CGRect(
            x: metrics.center.x - metrics.radius,
            y: metrics.center.y - metrics.radius,
            width: metrics.radius * 2,
            height: metrics.radius * 2
        )
    }

    private var visibleArcs: [VisibleArc] {
        tasks.compactMap { task in
            DialGeometry.visibleMinutes(start: task.start, end: task.end, segment: segment, day: day)
                .map { VisibleArc(task: task, minutes: $0) }
        }
    }

    /// Dragging along a lane sketches a new task on it.
    private var createGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard let lane = preview?.lane ?? metrics.lane(at: value.startLocation) else { return }
                let minutes = DialGeometry.dragRange(
                    from: DialGeometry.minutes(at: value.startLocation, center: metrics.center),
                    to: DialGeometry.minutes(at: value.location, center: metrics.center),
                    in: segment
                )
                if let previous = preview?.minutes, previous != minutes {
                    // Every slot clicks under the finger like a detent; whole hours click harder.
                    let moved = previous.upperBound != minutes.upperBound ? minutes.upperBound : minutes.lowerBound
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        moved.isMultiple(of: 60) ? .levelChange : .alignment,
                        performanceTime: .now
                    )
                }
                preview = Preview(lane: lane, minutes: minutes)
            }
            .onEnded { _ in
                if let preview, preview.minutes.upperBound > preview.minutes.lowerBound {
                    onCreate(preview.minutes, preview.lane)
                }
                preview = nil
            }
    }
}

/// The hand, told how much of the running focus session is left. Kept apart from `DialView` so the
/// timer's once-a-second updates redraw only this.
private struct LiveHand: View {
    @Environment(AppModel.self) private var model
    let day: Date
    let segment: DaySegment
    let metrics: DialMetrics

    var body: some View {
        let timer = model.timer
        ClockHand(
            day: day,
            segment: segment,
            metrics: metrics,
            focusMinutesLeft: timer.isFocusing ? Countdown.minutesRemaining(for: timer.remaining) : nil
        )
    }
}
