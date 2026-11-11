import SwiftUI

/// The morning sheet: type what matters, in order, and watch the day fill in around the routine.
struct PlanDayView: View {
    @Environment(AppModel.self) private var model

    @State private var items: [DayPlanner.Item]
    @State private var entry = ""
    @State private var entryMinutes = 60
    @State private var entryLane = TaskLane.focus
    @State private var showsRoutine = false
    @State private var now: Date
    @FocusState private var entryIsFocused: Bool
    private let fixedNow: Date?

    /// `items` and `now` are for previews; the sheet normally starts empty, at the present.
    init(items: [DayPlanner.Item] = [], now: Date? = nil) {
        _items = State(initialValue: items)
        _now = State(initialValue: now ?? .now)
        fixedNow = now
    }

    private static let durations = [30, 60, 90, 120]

    var body: some View {
        Group {
            if showsRoutine {
                RoutineEditor(isFirstRun: !model.routine.isSetUp) {
                    withAnimation(.snappy(duration: 0.3)) { showsRoutine = false }
                    entryIsFocused = true
                }
                .transition(.blurReplace)
            } else {
                planner
                    .transition(.blurReplace)
            }
        }
        .frame(width: 820, height: 600)
        .background(OdakPalette.paper)
        .onAppear {
            now = fixedNow ?? .now
            showsRoutine = !model.routine.isSetUp
            entryIsFocused = !showsRoutine
        }
        .interactiveDismissDisabled()
    }

    // MARK: Planning

    private var planner: some View {
        let today = Calendar.current.startOfDay(for: now)
        let existing = model.plans.tasks(on: today)
        let outline = DayOutline(routine: model.routine.routine, existing: existing, items: items, day: today, now: now)

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(OdakPalette.ink)
                Text(verbatim: now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OdakPalette.ink.opacity(0.55))
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    entryField
                    carryOver(today: today, existing: existing)
                    itemList(outline: outline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                DayOutlineView(outline: outline)
                    .frame(width: 290)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, 24)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.3)) { showsRoutine = true }
                } label: {
                    Label("Day Routine…", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(FooterButtonStyle())

                Spacer()

                Button("Not Today") {
                    model.closeDayPlan()
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button {
                    addEntry()
                    model.applyDayPlan(items: items, placements: DayOutline(routine: model.routine.routine, existing: existing, items: items, day: today, now: now).result.placements)
                } label: {
                    Label("Start the Day", systemImage: "sunrise.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .help(Text("⌘↩"))
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 36)
        .padding(.top, 34)
        .padding(.bottom, 26)
    }

    private var greeting: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private var entryField: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("What matters today, most important first")
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(entryLane.tint)
                    .frame(width: 4, height: 26)
                TextField("Type a task and press Return", text: $entry)
                    .textFieldStyle(.plain)
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(OdakPalette.ink)
                    .focused($entryIsFocused)
                    .onSubmit(addEntry)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(OdakPalette.face, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 14) {
                ChipPicker(options: Self.durations, selection: $entryMinutes) {
                    Text(verbatim: ActivityMath.durationText(minutes: $0))
                }
                Rectangle()
                    .fill(OdakPalette.ink.opacity(0.12))
                    .frame(width: 1, height: 16)
                ChipPicker(options: TaskLane.allCases, selection: $entryLane) { Text($0.title) }
            }
            .padding(.leading, -4)
        }
    }

    /// Yesterday's work, one click away from being today's.
    @ViewBuilder
    private func carryOver(today: Date, existing: [PlannedTask]) -> some View {
        let suggestions = carryOverSuggestions(today: today, existing: existing)
        let weekGoals = weekGoalSuggestions(existing: existing)
        if !weekGoals.isEmpty {
            HStack(spacing: 8) {
                SectionLabel("This Week")
                ForEach(weekGoals) { goal in
                    suggestionChip(goal.title) {
                        items.append(DayPlanner.Item(title: goal.title, minutes: entryMinutes, lane: .focus))
                    }
                }
            }
        }
        if !suggestions.isEmpty {
            HStack(spacing: 8) {
                SectionLabel("From yesterday")
                ForEach(suggestions) { task in
                    suggestionChip(task.title) {
                        let minutes = Int(task.end.timeIntervalSince(task.start) / 60)
                        items.append(DayPlanner.Item(title: task.title, minutes: min(max(minutes, 30), 180), lane: task.lane))
                    }
                }
            }
        }
    }

    private func suggestionChip(_ title: String, add: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25), add)
        } label: {
            Label {
                Text(verbatim: title).lineLimit(1)
            } icon: {
                Image(systemName: "plus")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(OdakPalette.ink.opacity(0.75))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(OdakPalette.bands[0], in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Open goals of the week that are not in today yet.
    private func weekGoalSuggestions(existing: [PlannedTask]) -> [WeekGoal] {
        let taken = Set(existing.map(\.title)).union(items.map(\.title))
        return model.goals.visible()
            .filter { !$0.isDone && !taken.contains($0.title) }
            .prefix(3)
            .map { $0 }
    }

    private func carryOverSuggestions(today: Date, existing: [PlannedTask]) -> [PlannedTask] {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return [] }
        let routineTitles = Set(model.routine.routine.blocks.map(\.title))
        var taken = Set(existing.map(\.title)).union(items.map(\.title)).union(routineTitles)
        return model.plans.tasks(on: yesterday)
            .filter { $0.lane != .personal && taken.insert($0.title).inserted }
            .prefix(3)
            .map { $0 }
    }

    @ViewBuilder
    private func itemList(outline: DayOutline) -> some View {
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing yet.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OdakPalette.ink.opacity(0.6))
                Text("Each task lands in the first free time of the day, around your breaks. Three good ones are plenty.")
                    .font(.system(size: 13))
                    .foregroundStyle(OdakPalette.ink.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
        } else {
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ItemRow(
                        number: index + 1,
                        item: item,
                        leftOver: outline.result.leftOver[item.id],
                        onResize: { resize(item.id, by: $0) },
                        onRemove: { withAnimation(.snappy(duration: 0.25)) { items.removeAll { $0.id == item.id } } }
                    )
                    .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, -8)
        }
    }

    private func addEntry() {
        let title = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.25)) {
            items.append(DayPlanner.Item(title: title, minutes: entryMinutes, lane: entryLane))
        }
        entry = ""
    }

    private func resize(_ id: DayPlanner.Item.ID, by minutes: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].minutes = min(max(items[index].minutes + minutes, 30), 480)
    }
}

private struct ItemRow: View {
    let number: Int
    let item: DayPlanner.Item
    let leftOver: Int?
    let onResize: (Int) -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(OdakPalette.onTask)
                .frame(width: 22, height: 22)
                .background(item.lane.tint, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OdakPalette.ink)
                    .lineLimit(1)
                if let leftOver {
                    Text("\(ActivityMath.durationText(minutes: leftOver)) won't fit today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(OdakPalette.warning)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                stepButton("minus", help: "Shorter") { onResize(-30) }
                    .disabled(item.minutes <= 30)
                Text(verbatim: ActivityMath.durationText(minutes: item.minutes))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(OdakPalette.ink.opacity(0.75))
                    .frame(minWidth: 62)
                stepButton("plus", help: "Longer") { onResize(30) }
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(OdakPalette.ink.opacity(0.45))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.35)
            .help(Text("Remove"))
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(OdakPalette.face.opacity(isHovered ? 1 : 0.7), in: RoundedRectangle(cornerRadius: 10))
        .onHover { isHovered = $0 }
    }

    private func stepButton(_ systemImage: String, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(OdakPalette.ink.opacity(0.6))
                .frame(width: 22, height: 22)
                .background(OdakPalette.bands[0], in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(Text(help))
    }
}

/// The day as it will be once the sheet is confirmed: what is already there, the routine's
/// breaks, the new tasks and the free time between them.
struct DayOutline {
    struct Entry: Identifiable {
        enum Kind { case existing, routine, planned, free }

        let id = UUID()
        let kind: Kind
        let title: String
        let range: ClosedRange<Int>
        let lane: TaskLane?
    }

    let entries: [Entry]
    let result: DayPlanner.Result
    /// `nil` when the working day is already over.
    let window: ClosedRange<Int>?

    init(routine: DayRoutine, existing: [PlannedTask], items: [DayPlanner.Item], day: Date, now: Date) {
        let nowMinutes = DialGeometry.dayMinutes(for: now, on: day)
        func minutes(_ date: Date) -> Int { DialGeometry.dayMinutes(for: date, on: day) }

        var entries = existing
            .filter { minutes($0.end) > nowMinutes }
            .map { Entry(kind: .existing, title: $0.title, range: minutes($0.start)...minutes($0.end), lane: $0.lane) }
        for block in routine.activeBlocks where block.end > nowMinutes {
            let isThere = existing.contains { $0.title == block.title && minutes($0.start) == block.start }
            if !isThere {
                entries.append(Entry(kind: .routine, title: block.title, range: block.start...block.end, lane: .personal))
            }
        }
        let busy = entries.map(\.range)

        window = DayPlanner.window(routine: routine, nowMinutes: nowMinutes)
        if let window {
            result = DayPlanner.schedule(items, window: window, busy: busy)
            for placement in result.placements {
                guard let item = items.first(where: { $0.id == placement.item }) else { continue }
                entries.append(Entry(kind: .planned, title: item.title, range: placement.range, lane: item.lane))
            }
            let taken = entries.map(\.range)
            for gap in DayPlanner.gaps(in: window, busy: taken) {
                entries.append(Entry(kind: .free, title: "", range: gap, lane: nil))
            }
        } else {
            var result = DayPlanner.Result()
            for item in items {
                result.leftOver[item.id] = item.minutes
            }
            self.result = result
        }
        self.entries = entries.sorted { ($0.range.lowerBound, $0.range.upperBound) < ($1.range.lowerBound, $1.range.upperBound) }
    }
}

private struct DayOutlineView: View {
    let outline: DayOutline

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Your day")
                Spacer()
                if outline.window != nil, outline.result.freeMinutes > 0 {
                    Text("\(ActivityMath.durationText(minutes: outline.result.freeMinutes)) free")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OdakPalette.ink.opacity(0.5))
                }
            }

            if outline.window == nil && outline.entries.isEmpty {
                Text("The working day is over. Change its hours in Day Routine, or plan tomorrow in the morning.")
                    .font(.system(size: 13))
                    .foregroundStyle(OdakPalette.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(outline.entries) { entry in
                        row(entry)
                            .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.3), value: outline.entries.map(\.range))
            }
            .scrollIndicators(.never)
        }
        .padding(16)
        .background(OdakPalette.bands[0].opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func row(_ entry: DayOutline.Entry) -> some View {
        let length = entry.range.upperBound - entry.range.lowerBound
        // Longer blocks are taller, within reason, so the column reads like the day.
        let height = min(max(CGFloat(length) / 30 * 17, 30), 86)
        HStack(alignment: .top, spacing: 10) {
            Text(verbatim: Self.time(entry.range.lowerBound))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(OdakPalette.ink.opacity(0.5))
                .frame(width: 40, alignment: .trailing)
                .padding(.top, 7)

            Group {
                if entry.kind == .free {
                    Text("Free · \(ActivityMath.durationText(minutes: length))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(OdakPalette.ink.opacity(0.4))
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(OdakPalette.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                } else {
                    let tint = entry.lane?.tint ?? OdakPalette.ink
                    let isNew = entry.kind == .planned
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: entry.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(isNew ? OdakPalette.onTask : OdakPalette.ink.opacity(0.8))
                            .lineLimit(1)
                        Text(verbatim: ActivityMath.durationText(minutes: length))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isNew ? OdakPalette.onTask.opacity(0.8) : OdakPalette.ink.opacity(0.45))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
                    .background(isNew ? tint : tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .leading) {
                        if !isNew {
                            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3).padding(.vertical, 5).padding(.leading, 3)
                        }
                    }
                }
            }
        }
    }

    static func time(_ minutes: Int) -> String {
        DialGeometry.date(forDayMinutes: minutes, on: .now).formatted(date: .omitted, time: .shortened)
    }
}
