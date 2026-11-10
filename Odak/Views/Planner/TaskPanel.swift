import SwiftUI

struct TaskPanel: View {
    @Environment(AppModel.self) private var model
    let day: Date
    let tasks: [PlannedTask]
    let selectedTask: PlannedTask?
    let onEdit: (PlannedTask) -> Void

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let shownTask = selectedTask ?? (isToday ? tasks.first(where: { $0.contains(now) }) : nil)
        let reference = isToday ? now : calendar.startOfDay(for: day)
        let upcoming = Array(tasks.filter { $0.start >= reference && $0.id != shownTask?.id }.prefix(3))

        VStack(alignment: .leading, spacing: 28) {
            if model.timer.isActive {
                FocusPanel()
                    .transition(.blurReplace)
            } else if let shownTask {
                CurrentTaskView(task: shownTask, now: now, onEdit: onEdit)
                    .id(shownTask.id)
                    .transition(.blurReplace)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing planned for now")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(OdakPalette.ink.opacity(0.75))
                    Text("Drag along a ring to plan a task.")
                        .foregroundStyle(OdakPalette.ink.opacity(0.5))
                    Button {
                        model.startFocus()
                    } label: {
                        Label("Start Focus", systemImage: "scope")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 10)
                }
                .transition(.blurReplace)
            }

            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Up Next")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .kerning(0.8)
                        .foregroundStyle(OdakPalette.ink.opacity(0.5))
                    ForEach(upcoming) { task in
                        UpcomingTaskRow(task: task)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.snappy(duration: 0.3), value: shownTask?.id)
        .animation(.snappy(duration: 0.35), value: model.timer.isActive)
    }
}

private struct CurrentTaskView: View {
    @Environment(AppModel.self) private var model
    let task: PlannedTask
    let now: Date
    let onEdit: (PlannedTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(task.lane.title)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(OdakPalette.onTask)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(task.lane.tint, in: Capsule())
                Text(verbatim: task.timeRangeText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OdakPalette.ink.opacity(0.6))
            }

            Text(task.title)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(OdakPalette.ink)
                .lineLimit(2)

            if !task.note.isEmpty {
                Text(task.note)
                    .foregroundStyle(OdakPalette.ink.opacity(0.6))
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                Button {
                    if let focusMinutes {
                        model.startFocus(minutes: focusMinutes, intention: task.title)
                    }
                } label: {
                    Label("Start Focus", systemImage: "scope")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(focusMinutes == nil)

                Button("Edit…") {
                    onEdit(task)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.top, 4)

            if let focusMinutes {
                Text("Focus for \(focusMinutes) min, until the task ends.")
                    .font(.caption)
                    .foregroundStyle(OdakPalette.ink.opacity(0.5))
            }
        }
    }

    private var focusMinutes: Int? {
        let seconds = task.end.timeIntervalSince(max(now, task.start))
        guard seconds >= 60 else { return nil }
        return Preferences.clamped(Int((seconds / 60).rounded(.up)), to: Preferences.focusRange)
    }
}

private struct UpcomingTaskRow: View {
    let task: PlannedTask

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.lane.tint)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .foregroundStyle(OdakPalette.ink)
                    .lineLimit(1)
                Text(verbatim: task.timeRangeText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(OdakPalette.ink.opacity(0.55))
            }
        }
    }
}
