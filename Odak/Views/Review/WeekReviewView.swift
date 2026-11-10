import SwiftUI

/// What the week looked like: hours per day, time per project and what was committed.
struct WeekReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var anchor: Date
    @State private var commits: [String: [Commit]] = [:]
    @State private var isLoadingCommits = true
    @State private var expanded: Set<String> = []

    init(date: Date = .now) {
        _anchor = State(initialValue: date)
    }

    private struct Row: Identifiable {
        let name: String
        let minutes: Int
        let commits: [Commit]

        var id: String { name }
    }

    var body: some View {
        let days = WeekReview.days(ofWeekContaining: anchor)
        let review = WeekReview(days: days) { model.activity.slots(on: $0) }
        let rows = rows(for: review)
        let colors = ReviewPalette.colors(for: rows.filter { $0.minutes > 0 }.map(\.name))

        VStack(alignment: .leading, spacing: 0) {
            header(days: days)

            HStack(alignment: .firstTextBaseline, spacing: 36) {
                figure(ActivityMath.durationText(minutes: review.totalMinutes), "Worked", isHero: true)
                figure(ActivityMath.durationText(minutes: focusMinutes(in: days)), "In focus sessions")
                figure(isLoadingCommits ? "…" : "\(rows.reduce(0) { $0 + $1.commits.count })", "Commits")
                figure("\(rows.count)", "Projects")
            }
            .padding(.top, 22)

            DailyBars(review: review, colors: colors)
                .padding(.top, 22)

            Divider()
                .overlay(PlannerPalette.ink.opacity(0.08))
                .padding(.top, 18)

            if rows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { row in
                            ProjectRow(
                                name: row.name,
                                minutes: row.minutes,
                                commits: row.commits,
                                color: colors[row.name] ?? ReviewPalette.other,
                                isExpanded: expanded.contains(row.name)
                            ) {
                                withAnimation(.snappy(duration: 0.25)) {
                                    expanded.formSymmetricDifference([row.name])
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Text("Time is estimated from file changes in \(Preferences.activityFolder.lastPathComponent). Pauses of up to \(ActivityMath.maxGapSlots * ActivityMath.slotMinutes) minutes count as work.")
                .font(.caption)
                .foregroundStyle(PlannerPalette.ink.opacity(0.45))
                .padding(.top, 10)
        }
        .padding(30)
        .frame(width: 760, height: 640)
        .background(PlannerPalette.paper)
        .task(id: days.first) {
            isLoadingCommits = true
            let interval = DateInterval(start: days.first ?? anchor, duration: 7 * 86_400)
            let loaded = await GitHistory.commits(under: Preferences.activityFolder, in: interval)
            guard !Task.isCancelled else { return }
            commits = loaded
            isLoadingCommits = false
        }
    }

    private func header(days: [Date]) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your week")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(PlannerPalette.ink)
                if let first = days.first, let last = days.last {
                    Text(verbatim: (first..<last).formatted(.interval.day().month(.wide)))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PlannerPalette.ink.opacity(0.55))
                }
            }
            Spacer()
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help(Text("Previous Week"))
            Button("This Week") {
                anchor = .now
            }
            .disabled(Calendar.current.isDate(anchor, equalTo: .now, toGranularity: .weekOfYear))
            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help(Text("Next Week"))
            .disabled(Calendar.current.isDate(anchor, equalTo: .now, toGranularity: .weekOfYear))

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.leading, 8)
        }
    }

    private func figure(_ value: String, _ label: LocalizedStringKey, isHero: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: isHero ? 40 : 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PlannerPalette.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(PlannerPalette.ink.opacity(0.5))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isLoadingCommits ? "Reading your repositories…" : "Nothing recorded this week")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PlannerPalette.ink.opacity(0.75))
            if !Preferences.trackActivity {
                Text("Project tracking is off. Turn it on in Settings → General.")
                    .foregroundStyle(PlannerPalette.ink.opacity(0.5))
            } else {
                Text("Odak notes which project you work on whenever files change in \(Preferences.activityFolder.lastPathComponent).")
                    .foregroundStyle(PlannerPalette.ink.opacity(0.5))
            }
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Projects with tracked time or commits: most time first, then most commits.
    private func rows(for review: WeekReview) -> [Row] {
        let tracked = Dictionary(uniqueKeysWithValues: review.projects.map { ($0.name, $0.minutes) })
        return Set(tracked.keys).union(commits.keys)
            .map { Row(name: $0, minutes: tracked[$0] ?? 0, commits: commits[$0] ?? []) }
            .sorted { ($0.minutes, $0.commits.count, $1.name) > ($1.minutes, $1.commits.count, $0.name) }
    }

    private func focusMinutes(in days: [Date]) -> Int {
        guard let start = days.first else { return 0 }
        let interval = DateInterval(start: start, duration: 7 * 86_400)
        return model.history.sessions.filter { interval.contains($0.start) }.focusedMinutes
    }

    private func shiftWeek(by weeks: Int) {
        if let shifted = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: anchor) {
            anchor = shifted
        }
    }
}

private struct ProjectRow: View {
    let name: String
    let minutes: Int
    let commits: [Commit]
    let color: Color
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(minutes > 0 ? color : PlannerPalette.ink.opacity(0.15))
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: (name as NSString).lastPathComponent)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PlannerPalette.ink)
                        let parent = (name as NSString).deletingLastPathComponent
                        if !parent.isEmpty {
                            Text(verbatim: parent)
                                .font(.caption)
                                .foregroundStyle(PlannerPalette.ink.opacity(0.45))
                        }
                    }

                    Spacer()

                    if !commits.isEmpty {
                        Text("\(commits.count) commits")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PlannerPalette.ink.opacity(0.55))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PlannerPalette.ink.opacity(0.35))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }

                    Text(verbatim: ActivityMath.durationText(minutes: minutes))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(PlannerPalette.ink.opacity(minutes > 0 ? 1 : 0.35))
                        .frame(width: 84, alignment: .trailing)
                }
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!commits.isEmpty)

            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(commits) { commit in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(commit.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(PlannerPalette.ink.opacity(0.45))
                                .frame(width: 78, alignment: .leading)
                            Text(verbatim: commit.subject)
                                .font(.system(size: 13))
                                .foregroundStyle(PlannerPalette.ink.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.leading, 24)
                .padding(.bottom, 10)
                .transition(.opacity)
            }
        }
    }
}
