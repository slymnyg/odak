import AppKit
import UserNotifications

@MainActor
final class Notifier {
    private var hasRequestedAuthorization = false
    /// The test host shares the app's notification centre; tests must not schedule into it.
    private let isLive = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil

    func requestAuthorizationIfNeeded() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static let planDayIdentifier = "plan-day"
    private static let taskPrefix = "task-"

    /// One reminder per upcoming task, replacing whatever was scheduled before.
    /// `lead` is minutes before the start; `nil` clears them all.
    func scheduleTaskReminders(for tasks: [PlannedTask], lead: Int?, now: Date = .now) {
        guard isLive else { return }
        let center = UNUserNotificationCenter.current()
        // The system keeps at most 64 pending requests per app.
        let upcoming = lead.map { lead in
            tasks
                .map { (task: $0, fire: $0.start.addingTimeInterval(TimeInterval(-lead * 60))) }
                .filter { $0.fire > now.addingTimeInterval(5) }
                .sorted { $0.fire < $1.fire }
                .prefix(40)
        } ?? []
        let requests = upcoming.map { entry in
            let content = UNMutableNotificationContent()
            content.title = entry.task.title
            let time = entry.task.start.formatted(date: .omitted, time: .shortened)
            content.body = lead == 0 ? String(localized: "Starting now, until \(entry.task.end.formatted(date: .omitted, time: .shortened)).") : String(localized: "Starts at \(time).")
            content.sound = .default
            return UNNotificationRequest(
                identifier: Self.taskPrefix + entry.task.id.uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: entry.fire.timeIntervalSince(now), repeats: false)
            )
        }
        if !requests.isEmpty {
            requestAuthorizationIfNeeded()
        }
        Task {
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.taskPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            for request in requests {
                try? await center.add(request)
            }
        }
    }

    /// The morning invitation to plan the day, at `date`; `nil` cancels it.
    func schedulePlanDayInvitation(at date: Date?, now: Date = .now) {
        guard isLive else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.planDayIdentifier])
        guard let date, date > now else { return }
        requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Plan your day")
        content.body = String(localized: "A minute now saves the day from drifting. Your routine is already in place.")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.planDayIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSince(now), repeats: false)
        )
        Task {
            try? await center.add(request)
        }
    }

    func playCompletionSound() {
        NSSound(named: "Glass")?.play()
    }
}
