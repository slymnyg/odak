import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    let timer = FocusTimer()
    let history: SessionStore
    let plans: PlanStore
    let activity: ActivityStore
    let routine: RoutineStore
    let goals: GoalStore
    let notifier: Notifier
    let blocking: BlockingController
    let focusScreen = FocusScreenController()
    let planner = PlannerWindowController()

    var intention = ""
    private(set) var isFocusScreenVisible = false
    /// True while the planner should be showing the "plan the day" sheet.
    var isPlanningDay = false
    /// A short confirmation shown at the foot of the planner, such as where a task was moved to.
    private(set) var planNotice: PlanNotice? = nil

    @ObservationIgnored private var ticker: Task<Void, Never>? = nil
    @ObservationIgnored private var activityWatcher: ActivityWatcher?
    @ObservationIgnored private var activitySaver: Timer?
    @ObservationIgnored private var storageWatcher: FolderWatcher?
    @ObservationIgnored private var dayRhythm: Timer?

    /// Where plans, history and project time are kept right now.
    private(set) var storage: Storage

    init(storage: Storage? = nil, plans: PlanStore? = nil, activity: ActivityStore? = nil) {
        let storage = storage ?? Storage.standard()
        self.storage = storage
        self.plans = plans ?? PlanStore(folder: storage.plans)
        self.activity = activity ?? ActivityStore(folder: storage.activity, device: storage.device)
        history = SessionStore(folder: storage.sessions, device: storage.device)
        routine = RoutineStore(folder: storage.root)
        goals = GoalStore(folder: storage.goals)
        let notifier = Notifier()
        self.notifier = notifier
        blocking = BlockingController(notifier: notifier)
        blocking.blockedPageContext = { [weak self] in
            guard let self else { return BlockedPage.Context() }
            return BlockedPage.context(intention: intention, tasks: self.plans.tasks(on: .now), now: .now)
        }
    }

    /// Watches the data folder, so what another Mac writes through a synced folder shows up here.
    func startWatchingStorage() {
        storageWatcher?.stop()
        for folder in [storage.plans, storage.sessions, storage.activity] {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let watcher = FolderWatcher(folders: [storage.root]) { [weak self] in
            self?.plans.reload()
            self?.history.reload()
            self?.activity.reload()
            self?.routine.reload()
            self?.goals.reload()
        }
        watcher.start()
        storageWatcher = watcher
    }

    /// Moves everything to `folder` (`nil` for the local one), merging with what is already there.
    /// Returns `false`, changing nothing, when the folder cannot be used.
    @discardableResult
    func moveData(to folder: URL?) -> Bool {
        let root = folder ?? Storage.localRoot
        guard Storage.isReachable(root) else { return false }
        Preferences.dataFolder = folder
        let wasWatching = storageWatcher != nil
        storageWatcher?.stop()
        storageWatcher = nil
        storage = Storage(root: root, device: storage.device)
        plans.relocate(to: storage.plans)
        history.relocate(to: storage.sessions)
        activity.relocate(to: storage.activity)
        routine.relocate(to: storage.root)
        goals.relocate(to: storage.goals)
        if wasWatching {
            startWatchingStorage()
        }
        return true
    }

    /// Starts (or restarts, after a settings change) watching the projects folder.
    func startActivityTracking() {
        stopActivityTracking()
        let folder = Preferences.activityFolder
        var isDirectory: ObjCBool = false
        guard Preferences.trackActivity,
              FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else { return }

        let watcher = ActivityWatcher(root: folder) { [weak self] projects in
            self?.activity.record(projects, at: .now)
        }
        watcher.start()
        activityWatcher = watcher
        activitySaver = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.activity.flush()
            }
        }
    }

    func stopActivityTracking() {
        activityWatcher?.stop()
        activityWatcher = nil
        activitySaver?.invalidate()
        activitySaver = nil
        activity.flush()
    }

    func primaryAction() {
        switch timer.status {
        case .idle where timer.phase == .focus: startFocus()
        case .idle: startBreak(timer.phase)
        case .running: pause()
        case .paused: resume()
        }
    }

    func startFocus(minutes: Int? = nil, intention: String? = nil) {
        if let intention {
            self.intention = intention
        }
        notifier.requestAuthorizationIfNeeded()
        timer.start(.focus, minutes: minutes ?? Preferences.focusMinutes)
        blocking.activate(until: timer.endsAt)
        startTicker()
        if Preferences.showFocusScreen {
            showFocusScreen()
        }
    }

    // Blocking stays on while paused so a pause can't be used to slip into distractions.
    func pause() {
        timer.pause()
        ticker?.cancel()
        blocking.updateDeadline(nil)
    }

    func resume() {
        timer.resume()
        blocking.updateDeadline(timer.endsAt)
        startTicker()
    }

    func stop() {
        let wasFocusing = timer.isFocusing
        ticker?.cancel()
        timer.stop()
        hideFocusScreen()
        if wasFocusing {
            blocking.deactivate()
        }
    }

    func blockingPreferenceChanged() {
        guard timer.isFocusing else { return }
        if Preferences.blockDistractions {
            blocking.activate(until: timer.endsAt)
        } else {
            blocking.deactivate()
        }
    }

    func installHelper() {
        if blocking.installHelper() {
            blockingPreferenceChanged()
        }
    }

    func showFocusScreen() {
        guard timer.isFocusing else { return }
        focusScreen.show(model: self)
        isFocusScreenVisible = true
    }

    func hideFocusScreen() {
        focusScreen.hide()
        isFocusScreenVisible = false
    }

    func showPlanner() {
        planner.show(model: self)
    }

    // MARK: Planning the day

    /// Opens the planner with the "plan the day" sheet.
    func planDay() {
        showPlanner()
        isPlanningDay = true
    }

    /// Starts the daily rhythm: the invitation to plan, checked every minute, and task reminders
    /// that follow the plan as it changes.
    func startDayRhythm() {
        offerDayPlanIfDue(bringForward: true)
        refreshReminders()
        observePlans()
        dayRhythm?.invalidate()
        dayRhythm = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.offerDayPlanIfDue(bringForward: false)
            }
        }
    }

    /// Once a day, from the chosen time on, the sheet is put up and the planner comes forward
    /// above everything else. A running focus session is not interrupted; the sheet follows it.
    func offerDayPlanIfDue(bringForward: Bool, now: Date = .now) {
        guard Preferences.planDay, !isPlanningDay, !timer.isActive,
              Preferences.lastPlannedDay != PlanFiles.key(for: now),
              DialGeometry.dayMinutes(for: now, on: now) >= Preferences.planDayMinutes
        else { return }
        if bringForward {
            planDay()
        } else {
            isPlanningDay = true
            planner.showOnTop(model: self)
        }
    }

    /// Today has been planned or waved off; the invitation moves to tomorrow.
    func closeDayPlan() {
        isPlanningDay = false
        planner.settle()
        Preferences.lastPlannedDay = PlanFiles.key(for: .now)
        refreshReminders()
    }

    /// Writes the routine's breaks and the placed items into today's plan.
    func applyDayPlan(items: [DayPlanner.Item], placements: [DayPlanner.Placement], now: Date = .now) {
        let today = Calendar.current.startOfDay(for: now)
        func date(_ minutes: Int) -> Date { DialGeometry.date(forDayMinutes: minutes, on: today) }
        let existing = plans.tasks(on: today)

        for block in routine.routine.activeBlocks where date(block.end) > now {
            let alreadyThere = existing.contains { $0.title == block.title && $0.start == date(block.start) }
            if !alreadyThere {
                plans.save(PlannedTask(title: block.title, note: "", start: date(block.start), end: date(block.end), lane: .personal))
            }
        }
        for placement in placements {
            guard let item = items.first(where: { $0.id == placement.item }) else { continue }
            plans.save(PlannedTask(
                title: item.title,
                note: "",
                start: date(placement.range.lowerBound),
                end: date(placement.range.upperBound),
                lane: item.lane
            ))
        }
        closeDayPlan()
    }

    /// Places one piece of work in the first free time left today. Returns `false` when the
    /// working day has no room for all of it.
    @discardableResult
    func fitIntoToday(title: String, minutes: Int, now: Date = .now) -> Bool {
        let today = Calendar.current.startOfDay(for: now)
        let item = DayPlanner.Item(title: title, minutes: minutes)
        let outline = DayOutline(routine: routine.routine, existing: plans.tasks(on: today), items: [item], day: today, now: now)
        guard outline.result.leftOver.isEmpty, !outline.result.placements.isEmpty else { return false }
        for placement in outline.result.placements {
            plans.save(PlannedTask(
                title: title,
                note: "",
                start: DialGeometry.date(forDayMinutes: placement.range.lowerBound, on: today),
                end: DialGeometry.date(forDayMinutes: placement.range.upperBound, on: today),
                lane: .focus
            ))
        }
        return true
    }

    // MARK: Postponing

    enum Postponement {
        /// Push the task back, and the focus work after it that it would run into.
        case later(minutes: Int)
        /// The first free time left today.
        case nextFree
        /// The first free time of the next day.
        case tomorrow
    }

    struct PlanNotice: Equatable, Identifiable {
        let id = UUID()
        let text: String
        var isWarning = false
    }

    /// Moves a task that did not happen when planned. Meetings and breaks are treated as fixed:
    /// nothing is moved onto them and they are never moved to make room. Returns `false`, changing
    /// nothing, when there is no room.
    @discardableResult
    func postpone(_ task: PlannedTask, _ how: Postponement, now: Date = .now) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let taskDay = calendar.startOfDay(for: task.start)
        let length = max(Int(task.end.timeIntervalSince(task.start) / 60), DayPlanner.step)
        var day = max(taskDay, today)
        var moving = [task]
        var placements: [DayPlanner.Placement] = []
        var items: [DayPlanner.Item] = []

        switch how {
        case .later(let minutes):
            day = taskDay
            func dayMinutes(_ date: Date) -> Int { DialGeometry.dayMinutes(for: date, on: day) }
            let onDay = plans.tasks(on: day)
            // The task, and the focus work planned after it, keep their order and slide together.
            moving = onDay.filter { $0.id == task.id || ($0.lane == .focus && $0.start >= task.start) }
            let fixed = onDay.filter { other in !moving.contains { $0.id == other.id } }
            var start = dayMinutes(task.start) + minutes
            if day == today {
                start = max(start, dayMinutes(now))
            }
            start = DayPlanner.roundedUp(start)
            guard DialGeometry.minutesPerDay - start >= DayPlanner.step else { return fail() }
            // Each one goes no earlier than it was, and no earlier than the one before it ends:
            // work is only ever pushed back, never pulled forward into a gap.
            var busy = fixed.map { dayMinutes($0.start)...dayMinutes($0.end) }
            var cursor = start
            for moved in moving {
                let item = DayPlanner.Item(
                    id: moved.id,
                    title: moved.title,
                    minutes: max(Int(moved.end.timeIntervalSince(moved.start) / 60), DayPlanner.step),
                    lane: moved.lane
                )
                let earliest = moved.id == task.id ? cursor : max(cursor, DayPlanner.roundedUp(dayMinutes(moved.start)))
                guard DialGeometry.minutesPerDay - earliest >= DayPlanner.step else { return fail() }
                let result = DayPlanner.schedule([item], window: earliest...DialGeometry.minutesPerDay, busy: busy)
                guard result.leftOver.isEmpty, let last = result.placements.last else { return fail() }
                items.append(item)
                placements += result.placements
                busy += result.placements.map(\.range)
                cursor = last.range.upperBound
            }

        case .nextFree, .tomorrow:
            if case .tomorrow = how {
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            }
            let item = DayPlanner.Item(id: task.id, title: task.title, minutes: length, lane: task.lane)
            let others = plans.tasks(on: day).filter { $0.id != task.id }
            let outline = DayOutline(routine: routine.routine, existing: others, items: [item], day: day, now: max(now, day))
            guard outline.result.leftOver.isEmpty, !outline.result.placements.isEmpty else { return fail() }
            items = [item]
            placements = outline.result.placements
        }

        // The first stretch an item gets is the task itself, moved; a task split by something
        // fixed continues as a new task after it.
        var seen = Set<PlannedTask.ID>()
        for placement in placements {
            guard var moved = moving.first(where: { $0.id == placement.item }) else { continue }
            if !seen.insert(moved.id).inserted {
                moved.id = UUID()
            }
            moved.start = DialGeometry.date(forDayMinutes: placement.range.lowerBound, on: day)
            moved.end = DialGeometry.date(forDayMinutes: placement.range.upperBound, on: day)
            plans.save(moved)
        }

        if let first = placements.first(where: { $0.item == task.id }) {
            let time = DialGeometry.date(forDayMinutes: first.range.lowerBound, on: day).formatted(date: .omitted, time: .shortened)
            let text: String
            if calendar.isDate(day, inSameDayAs: today) {
                text = String(localized: "Moved to \(time)")
            } else if calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today) ?? today) {
                text = String(localized: "Moved to tomorrow, \(time)")
            } else {
                text = String(localized: "Moved to \(day.formatted(.dateTime.weekday(.wide))), \(time)")
            }
            show(PlanNotice(text: text))
        }
        return true

        func fail() -> Bool {
            show(PlanNotice(text: String(localized: "No free time for it there"), isWarning: true))
            return false
        }
    }

    private func show(_ notice: PlanNotice) {
        planNotice = notice
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            if planNotice?.id == notice.id {
                planNotice = nil
            }
        }
    }

    /// Reschedules the invitation and the task reminders from the current plan and settings.
    func refreshReminders(now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let lead = Preferences.taskReminderLead
        notifier.scheduleTaskReminders(
            for: plans.tasks(on: today) + plans.tasks(on: tomorrow),
            lead: lead == Preferences.noReminder ? nil : lead,
            now: now
        )

        var invitation: Date? = nil
        if Preferences.planDay {
            let isDoneToday = Preferences.lastPlannedDay == PlanFiles.key(for: now)
            let todays = DialGeometry.date(forDayMinutes: Preferences.planDayMinutes, on: today)
            invitation = !isDoneToday && todays > now ? todays : DialGeometry.date(forDayMinutes: Preferences.planDayMinutes, on: tomorrow)
        }
        notifier.schedulePlanDayInvitation(at: invitation, now: now)
    }

    private func observePlans() {
        withObservationTracking {
            _ = plans.allTasks
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refreshReminders()
                self?.observePlans()
            }
        }
    }

    private func startBreak(_ phase: FocusTimer.Phase) {
        let minutes = phase == .longBreak ? Preferences.longBreakMinutes : Preferences.shortBreakMinutes
        timer.start(phase, minutes: minutes)
        startTicker()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled, let delay = self?.secondsUntilNextTick {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private var secondsUntilNextTick: Double {
        let fraction = timer.remaining - timer.remaining.rounded(.down)
        return fraction > 0.01 ? fraction : 1
    }

    private func tick() {
        guard let completion = timer.tick() else { return }
        ticker?.cancel()
        switch completion.phase {
        case .focus: finishFocus(completion)
        case .shortBreak, .longBreak: finishBreak()
        }
    }

    private func finishFocus(_ completion: FocusTimer.Completion) {
        blocking.deactivate()
        hideFocusScreen()
        let session = Session(completion: completion, intention: intention)
        history.record(session)
        announce(
            title: String(localized: "Focus session complete"),
            body: String(localized: "You focused for \(session.actualMinutes) min. Time for a break.")
        )

        let next = timer.nextBreak(longBreakEvery: Preferences.longBreakInterval)
        if Preferences.autoStartBreaks {
            startBreak(next)
        } else {
            timer.prepare(next)
        }
    }

    private func finishBreak() {
        timer.prepare(.focus)
        announce(
            title: String(localized: "Break is over"),
            body: String(localized: "Ready for the next focus session?")
        )
    }

    private func announce(title: String, body: String) {
        notifier.post(title: title, body: body)
        if Preferences.playSound {
            notifier.playCompletionSound()
        }
    }
}
