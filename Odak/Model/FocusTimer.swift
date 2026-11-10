import Foundation
import Observation

@Observable
@MainActor
final class FocusTimer {
    enum Phase: Equatable {
        case focus, shortBreak, longBreak

        var isBreak: Bool { self != .focus }
    }

    enum Status: Equatable {
        case idle, running, paused
    }

    struct Completion: Equatable {
        let phase: Phase
        let startedAt: Date
        let endedAt: Date
        let plannedDuration: TimeInterval
        let pausedDuration: TimeInterval

        var activeDuration: TimeInterval { endedAt.timeIntervalSince(startedAt) - pausedDuration }
    }

    private(set) var phase: Phase = .focus
    private(set) var status: Status = .idle
    private(set) var remaining: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var completedFocusSessions = 0

    @ObservationIgnored private var endDate: Date? = nil
    @ObservationIgnored private var startedAt: Date? = nil
    @ObservationIgnored private var pausedAt: Date? = nil
    @ObservationIgnored private var pausedDuration: TimeInterval = 0
    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    var isActive: Bool { status != .idle }
    var isFocusing: Bool { phase == .focus && isActive }
    var endsAt: Date? { status == .running ? endDate : nil }

    func start(_ phase: Phase, minutes: Int) {
        let start = now()
        self.phase = phase
        duration = TimeInterval(max(minutes, 1) * 60)
        remaining = duration
        startedAt = start
        endDate = start.addingTimeInterval(duration)
        pausedAt = nil
        pausedDuration = 0
        status = .running
    }

    func pause() {
        guard status == .running, let endDate else { return }
        let current = now()
        remaining = max(0, endDate.timeIntervalSince(current))
        pausedAt = current
        status = .paused
    }

    func resume() {
        guard status == .paused else { return }
        let current = now()
        if let pausedAt {
            pausedDuration += current.timeIntervalSince(pausedAt)
        }
        pausedAt = nil
        endDate = current.addingTimeInterval(remaining)
        status = .running
    }

    func stop() {
        prepare(.focus)
    }

    func prepare(_ phase: Phase) {
        self.phase = phase
        status = .idle
        remaining = 0
        duration = 0
        endDate = nil
        startedAt = nil
        pausedAt = nil
        pausedDuration = 0
    }

    @discardableResult
    func tick() -> Completion? {
        guard status == .running, let endDate, let startedAt else { return nil }
        remaining = max(0, endDate.timeIntervalSince(now()))
        guard remaining == 0 else { return nil }

        let completion = Completion(
            phase: phase,
            startedAt: startedAt,
            endedAt: endDate,
            plannedDuration: duration,
            pausedDuration: pausedDuration
        )
        if phase == .focus {
            completedFocusSessions += 1
        }
        status = .idle
        self.endDate = nil
        self.startedAt = nil
        return completion
    }

    func nextBreak(longBreakEvery interval: Int) -> Phase {
        guard interval > 0, completedFocusSessions > 0 else { return .shortBreak }
        return completedFocusSessions.isMultiple(of: interval) ? .longBreak : .shortBreak
    }
}
