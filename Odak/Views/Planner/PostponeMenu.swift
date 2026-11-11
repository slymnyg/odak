import SwiftUI

/// The ways to move a task that did not happen when planned. Used in the task's context menu
/// and behind the Postpone button.
struct PostponeItems: View {
    @Environment(AppModel.self) private var model
    let task: PlannedTask

    var body: some View {
        Button("30 Minutes Later") { model.postpone(task, .later(minutes: 30)) }
        Button("1 Hour Later") { model.postpone(task, .later(minutes: 60)) }
        Divider()
        Button("Next Free Time Today") { model.postpone(task, .nextFree) }
        Button("Tomorrow") { model.postpone(task, .tomorrow) }
    }
}

/// A line at the foot of the planner saying where a task went.
struct PlanNoticeView: View {
    let notice: AppModel.PlanNotice

    var body: some View {
        Label {
            Text(verbatim: notice.text)
        } icon: {
            Image(systemName: notice.isWarning ? "exclamationmark.circle.fill" : "arrow.turn.down.right")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(OdakPalette.paper)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(notice.isWarning ? OdakPalette.warning : OdakPalette.ink, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
    }
}
