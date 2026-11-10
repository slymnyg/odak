import AppKit

@MainActor
final class AppBlocker {
    private let notifier: Notifier
    private var blockedApps: [String: String] = [:]
    private var deadline: Date?
    private var observers: [NSObjectProtocol] = []
    private var lastNotified: [String: Date] = [:]
    private let notificationInterval: TimeInterval = 60

    init(notifier: Notifier) {
        self.notifier = notifier
    }

    func start(apps: [BlockedApp], until deadline: Date?) {
        stop()
        guard !apps.isEmpty else { return }
        blockedApps = Dictionary(apps.map { ($0.bundleIdentifier, $0.name) }, uniquingKeysWith: { first, _ in first })
        self.deadline = deadline

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated {
                    self?.handle(app)
                }
            }
            observers.append(observer)
        }

        NSWorkspace.shared.runningApplications
            .filter { isBlocked($0) }
            .forEach { $0.hide() }
    }

    func update(until deadline: Date?) {
        self.deadline = deadline
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        blockedApps.removeAll()
        lastNotified.removeAll()
        deadline = nil
    }

    private func isBlocked(_ app: NSRunningApplication) -> Bool {
        guard let identifier = app.bundleIdentifier else { return false }
        return blockedApps[identifier] != nil
    }

    private func handle(_ app: NSRunningApplication?) {
        guard let app, let identifier = app.bundleIdentifier, let name = blockedApps[identifier] else { return }
        app.hide()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if !app.isHidden, blockedApps[identifier] != nil {
                app.hide()
            }
        }
        notifyIfNeeded(name: name, identifier: identifier)
    }

    private func notifyIfNeeded(name: String, identifier: String) {
        let now = Date()
        if let last = lastNotified[identifier], now.timeIntervalSince(last) < notificationInterval { return }
        lastNotified[identifier] = now

        let body: String
        if let deadline {
            let time = deadline.formatted(date: .omitted, time: .shortened)
            body = String(localized: "\(name) is blocked until \(time).")
        } else {
            body = String(localized: "\(name) is blocked during your focus session.")
        }
        notifier.post(title: String(localized: "Stay focused"), body: body)
    }
}
