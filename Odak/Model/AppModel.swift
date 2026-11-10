import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    let timer = FocusTimer()
    let history = SessionStore()
    let plans: PlanStore
    let activity: ActivityStore
    let notifier: Notifier
    let blocking: BlockingController
    let focusScreen = FocusScreenController()
    let planner = PlannerWindowController()

    var intention = ""
    private(set) var isFocusScreenVisible = false

    @ObservationIgnored private var ticker: Task<Void, Never>? = nil
    @ObservationIgnored private var activityWatcher: ActivityWatcher?
    @ObservationIgnored private var activitySaver: Timer?

    init(plans: PlanStore? = nil, activity: ActivityStore? = nil) {
        self.plans = plans ?? PlanStore()
        self.activity = activity ?? ActivityStore()
        let notifier = Notifier()
        self.notifier = notifier
        blocking = BlockingController(notifier: notifier)
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
