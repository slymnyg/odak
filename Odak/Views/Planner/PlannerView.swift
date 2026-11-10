import AppKit
import SwiftUI

struct PlannerView: View {
    @Environment(AppModel.self) private var model
    @State private var day: Date
    @State private var segment: DaySegment
    @State private var selectedTaskID: PlannedTask.ID? = nil
    @State private var draft: TaskDraft? = nil
    @State private var showsReview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(date: Date = .now) {
        _day = State(initialValue: Calendar.current.startOfDay(for: date))
        _segment = State(initialValue: DaySegment(containing: date))
    }

    var body: some View {
        let tasks = model.plans.tasks(on: day)
        GeometryReader { geometry in
            let metrics = DialMetrics(size: geometry.size, half: segment.clockHalf)
            let dialOnTrailingEdge = segment.clockHalf == .left
            ZStack {
                DaylightGlow(segment: segment, center: metrics.center, radius: metrics.radius)
                    .id(segment)
                    .transition(.opacity)
                    .zIndex(-1)

                DialView(
                    day: day,
                    segment: segment,
                    metrics: metrics,
                    tasks: tasks,
                    selectedTaskID: $selectedTaskID,
                    onCreate: createTask,
                    onEdit: edit,
                    onDelete: delete
                )
                .id(segment)
                .transition(reduceMotion ? .opacity : .dialSpin(around: metrics.center, in: geometry.size))
                .zIndex(0)

                sidebar(tasks: tasks, dialOnTrailingEdge: dialOnTrailingEdge)
                    .frame(width: max(geometry.size.width - metrics.visibleWidth, 0))
                    .frame(maxWidth: .infinity, alignment: dialOnTrailingEdge ? .leading : .trailing)
                    .zIndex(1)
            }
            .animation(.spring(duration: 0.75, bounce: 0.24), value: segment)
            .animation(.snappy(duration: 0.3), value: day)
        }
        .background(OdakPalette.paper)
        .ignoresSafeArea()
        .frame(minWidth: 940, minHeight: 600)
        .sheet(item: $draft) { draft in
            TaskEditor(
                draft: draft,
                onSave: save,
                onDelete: draft.isNew ? nil : { deleteTask(withID: draft.id) }
            )
        }
        .sheet(isPresented: $showsReview) {
            WeekReviewView(date: day)
        }
        .onChange(of: day) {
            selectedTaskID = nil
        }
        .onChange(of: segment) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }

    /// Everything beside the dial. It swaps sides with the dial, so the add button stays next to it.
    private func sidebar(tasks: [PlannedTask], dialOnTrailingEdge: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PlannerHeader(day: $day, segment: $segment)

            TaskPanel(
                day: day,
                tasks: tasks,
                selectedTask: model.plans.task(withID: selectedTaskID),
                onEdit: edit
            )
            .padding(.top, 40)

            HStack(spacing: 10) {
                if !dialOnTrailingEdge {
                    addButton
                    Spacer(minLength: 0)
                    reviewButton
                }
                WeekStrip(day: $day) { model.plans.tasks(on: $0) }
                if dialOnTrailingEdge {
                    reviewButton
                    Spacer(minLength: 0)
                    addButton
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 52)
        .padding(.bottom, 26)
    }

    private var reviewButton: some View {
        Button {
            showsReview = true
        } label: {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OdakPalette.ink.opacity(0.7))
                .frame(width: 40, height: 40)
                .background(OdakPalette.bands[0], in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("r", modifiers: .command)
        .help(Text("Week in Review"))
        .accessibilityLabel(Text("Week in Review"))
    }

    private var addButton: some View {
        Button(action: addTask) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OdakPalette.onTask)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .buttonStyle(FloatingButtonStyle(tint: TaskLane.focus.tint))
        .keyboardShortcut("n", modifiers: .command)
        .help(Text("Add Task"))
        .accessibilityLabel(Text("Add Task"))
    }

    private func addTask() {
        let calendar = Calendar.current
        let now = Date.now
        let startSlot: Int
        if calendar.isDate(day, inSameDayAs: now) {
            let minutes = DialGeometry.dayMinutes(for: now, on: day)
            startSlot = min((minutes + DialGeometry.slotMinutes - 1) / DialGeometry.slotMinutes, TaskDraft.slotsPerDay - 2)
        } else {
            startSlot = 9 * 60 / DialGeometry.slotMinutes
        }
        draft = TaskDraft(day: day, startSlot: startSlot, endSlot: startSlot + 2)
    }

    private func createTask(in range: ClosedRange<Int>, lane: TaskLane) {
        draft = TaskDraft(
            day: day,
            startSlot: range.lowerBound / DialGeometry.slotMinutes,
            endSlot: range.upperBound / DialGeometry.slotMinutes,
            lane: lane
        )
    }

    private func edit(_ task: PlannedTask) {
        draft = TaskDraft(task: task, day: day)
    }

    private func save(_ task: PlannedTask) {
        model.plans.save(task)
        selectedTaskID = task.id
    }

    private func delete(_ task: PlannedTask) {
        model.plans.delete(task)
        if selectedTaskID == task.id {
            selectedTaskID = nil
        }
    }

    private func deleteTask(withID id: PlannedTask.ID) {
        if let task = model.plans.task(withID: id) {
            delete(task)
        }
    }
}

/// The round add button: it lifts and turns its plus on hover, and dips when pressed.
private struct FloatingButtonStyle: ButtonStyle {
    let tint: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rotationEffect(.degrees(isHovered ? 90 : 0))
            .background(tint, in: Circle())
            .shadow(color: tint.opacity(isHovered ? 0.5 : 0.35), radius: isHovered ? 14 : 10, y: isHovered ? 7 : 5)
            .scaleEffect(configuration.isPressed ? 0.9 : isHovered ? 1.06 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: isHovered)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

private struct DialSpin: ViewModifier {
    let degrees: Double
    let opacity: Double
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(degrees), anchor: anchor)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    /// The dial turns clockwise into place around its own hub, and keeps turning as it leaves.
    static func dialSpin(around center: CGPoint, in size: CGSize) -> AnyTransition {
        let anchor = UnitPoint(x: center.x / max(size.width, 1), y: center.y / max(size.height, 1))
        return .asymmetric(
            insertion: .modifier(
                active: DialSpin(degrees: -90, opacity: 0, anchor: anchor),
                identity: DialSpin(degrees: 0, opacity: 1, anchor: anchor)
            ),
            removal: .modifier(
                active: DialSpin(degrees: 90, opacity: 0, anchor: anchor),
                identity: DialSpin(degrees: 0, opacity: 1, anchor: anchor)
            )
        )
    }
}
