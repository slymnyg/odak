import SwiftUI

/// The week's open work in the planner sidebar: jot it down now, pick it up when there is time.
struct WeekGoalsSection: View {
    @Environment(AppModel.self) private var model
    @State private var entry = ""
    @FocusState private var entryIsFocused: Bool

    var body: some View {
        let goals = model.goals.visible()
        let worked = workedMinutes()
        let open = goals.filter { !$0.isDone }.count

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SectionLabel("This Week")
                if !goals.isEmpty {
                    Text(verbatim: "\(goals.count - open)/\(goals.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(OdakPalette.ink.opacity(0.4))
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(goals) { goal in
                        GoalRow(goal: goal, workedMinutes: worked[goal.title] ?? 0)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    addField
                }
                .animation(.snappy(duration: 0.25), value: goals.map(\.id))
                .animation(.snappy(duration: 0.25), value: open)
            }
            .scrollIndicators(.never)
            // Rows fade out at the bottom edge instead of being cut through.
            .mask(
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var addField: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(OdakPalette.ink.opacity(entryIsFocused ? 0.7 : 0.35))
                .frame(width: 16, height: 16)
            TextField("Something to finish this week", text: $entry)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .foregroundStyle(OdakPalette.ink)
                .focused($entryIsFocused)
                .onSubmit {
                    if model.goals.add(entry) != nil {
                        entry = ""
                    }
                    entryIsFocused = true
                }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(OdakPalette.face.opacity(entryIsFocused ? 0.9 : 0), in: RoundedRectangle(cornerRadius: 8))
        .animation(.easeOut(duration: 0.15), value: entryIsFocused)
    }

    /// Minutes of focus this week, by what the session was for.
    private func workedMinutes() -> [String: Int] {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return [:] }
        var minutes: [String: Int] = [:]
        for session in model.history.sessions where week.contains(session.start) {
            if let intention = session.intention {
                minutes[intention, default: 0] += session.actualMinutes
            }
        }
        return minutes
    }
}

private struct GoalRow: View {
    @Environment(AppModel.self) private var model
    let goal: WeekGoal
    let workedMinutes: Int

    @State private var isHovered = false
    @State private var note: Note? = nil

    private enum Note { case placed, noRoom }

    private static let focusChoices = [15, 30, 45, 60, 90]
    private static let planChoices = [30, 60, 90, 120]

    var body: some View {
        HStack(spacing: 9) {
            Button {
                model.goals.setDone(!goal.isDone, for: goal.id)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(OdakPalette.ink.opacity(goal.isDone ? 0 : 0.35), lineWidth: 1.5)
                    if goal.isDone {
                        Circle().fill(OdakPalette.accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(OdakPalette.onTask)
                    }
                }
                .frame(width: 16, height: 16)
                .contentShape(Rectangle().inset(by: -6))
            }
            .buttonStyle(.plain)
            .help(goal.isDone ? Text("Mark as Not Done") : Text("Mark as Done"))

            Text(verbatim: goal.title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(OdakPalette.ink.opacity(goal.isDone ? 0.4 : 0.9))
                .strikethrough(goal.isDone, color: OdakPalette.ink.opacity(0.4))
                .lineLimit(1)

            Spacer(minLength: 6)

            if let note {
                Group {
                    switch note {
                    case .placed: Text("Added to today")
                    case .noRoom: Text("No room today")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(note == .placed ? OdakPalette.accent : OdakPalette.warning)
                .transition(.opacity)
            } else if isHovered && !goal.isDone {
                startMenu
                    .transition(.opacity)
            } else if workedMinutes > 0 {
                Text(verbatim: ActivityMath.durationText(minutes: workedMinutes))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OdakPalette.ink.opacity(0.45))
                    .help(Text("Focused on this week"))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(OdakPalette.face.opacity(isHovered ? 0.8 : 0), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .contextMenu {
            if !goal.isDone {
                focusItems
                Divider()
                planItems
                Divider()
            }
            Button("Delete", role: .destructive) {
                model.goals.remove(goal.id)
            }
        }
    }

    /// Click to focus on it for half an hour; the arrow offers other lengths and a place in today.
    private var startMenu: some View {
        Menu {
            Section("Focus Now") { focusItems }
            Section("Fit Into Today") { planItems }
        } label: {
            Label {
                Text(verbatim: ActivityMath.durationText(minutes: 30))
            } icon: {
                Image(systemName: "play.fill")
            }
            .font(.system(size: 11, weight: .bold))
        } primaryAction: {
            focus(30)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(OdakPalette.accent)
        .fixedSize()
        .help(Text("Focus on this for 30 minutes"))
    }

    @ViewBuilder
    private var focusItems: some View {
        ForEach(Self.focusChoices, id: \.self) { minutes in
            Button {
                focus(minutes)
            } label: {
                Text("Focus for \(ActivityMath.durationText(minutes: minutes))")
            }
        }
    }

    @ViewBuilder
    private var planItems: some View {
        ForEach(Self.planChoices, id: \.self) { minutes in
            Button {
                show(model.fitIntoToday(title: goal.title, minutes: minutes) ? .placed : .noRoom)
            } label: {
                Text("\(ActivityMath.durationText(minutes: minutes)) later today")
            }
        }
    }

    private func focus(_ minutes: Int) {
        if model.timer.isActive {
            model.stop()
        }
        model.startFocus(minutes: minutes, intention: goal.title)
    }

    private func show(_ note: Note) {
        withAnimation(.easeOut(duration: 0.15)) { self.note = note }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.3)) { self.note = nil }
        }
    }
}
