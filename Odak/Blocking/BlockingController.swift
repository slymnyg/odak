import Foundation
import Observation

@Observable
@MainActor
final class BlockingController {
    private(set) var isHelperInstalled = HelperInstaller.isInstalled
    private(set) var lastError: String? = nil

    /// Supplies the session's intention and today's plan for the page blocked tabs land on.
    @ObservationIgnored var blockedPageContext: (() -> BlockedPage.Context)? {
        didSet { browserBlocker.pageContext = blockedPageContext }
    }

    private let siteBlocker = SiteBlocker()
    private let appBlocker: AppBlocker
    private let browserBlocker = BrowserBlocker()

    init(notifier: Notifier) {
        appBlocker = AppBlocker(notifier: notifier)
        browserBlocker.onPermissionDenied = { [weak self] browser in
            self?.lastError = String(localized: "Allow Odak to control \(browser) in System Settings → Privacy & Security → Automation to block websites there.")
        }
    }

    func activate(until deadline: Date?) {
        lastError = nil
        guard Preferences.blockDistractions else { return }

        appBlocker.start(apps: Preferences.blockedApps, until: deadline)

        let domains = DomainParser.parse(Preferences.blockedSites)
        guard !domains.isEmpty else { return }
        browserBlocker.start(domains: domains)
        guard isHelperInstalled else {
            lastError = String(localized: "Install the helper in Settings to block websites.")
            return
        }
        Task {
            do {
                try await siteBlocker.block(DomainParser.expand(domains))
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func updateDeadline(_ deadline: Date?) {
        appBlocker.update(until: deadline)
    }

    func deactivate() {
        appBlocker.stop()
        browserBlocker.stop()
        guard isHelperInstalled else { return }
        Task {
            do {
                try await siteBlocker.unblock()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func clearStaleBlocks() {
        refreshHelperStatus()
        guard isHelperInstalled else { return }
        Task {
            try? await siteBlocker.unblock()
        }
    }

    func clearBlocksBeforeExit() {
        appBlocker.stop()
        browserBlocker.stop()
        guard isHelperInstalled else { return }
        siteBlocker.unblockImmediately()
    }

    func refreshHelperStatus() {
        isHelperInstalled = HelperInstaller.isInstalled
    }

    @discardableResult
    func installHelper() -> Bool {
        defer { refreshHelperStatus() }
        do {
            try HelperInstaller.install()
            lastError = nil
            return true
        } catch HelperInstaller.Failure.cancelled {
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func uninstallHelper() {
        defer { refreshHelperStatus() }
        do {
            try HelperInstaller.uninstall()
            lastError = nil
        } catch HelperInstaller.Failure.cancelled {
            return
        } catch {
            lastError = error.localizedDescription
        }
    }
}
