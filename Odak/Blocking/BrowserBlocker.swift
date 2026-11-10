import AppKit

/// Steers browser tabs away from blocked sites during a session.
///
/// The hosts file stops every app that asks the system resolver, but browsers that resolve names
/// themselves (secure DNS, a VPN extension) or that still hold an open connection never see it.
/// This looks at the tabs instead, so it works whatever the browser does on the network.
/// macOS asks once per browser before Odak may script it.
@MainActor
final class BrowserBlocker {
    struct Browser {
        let bundleIdentifier: String
        let name: String
    }

    /// Browsers whose scripting dictionary has windows, tabs and a tab `URL`.
    static let browsers = [
        Browser(bundleIdentifier: "com.apple.Safari", name: "Safari"),
        Browser(bundleIdentifier: "com.google.Chrome", name: "Google Chrome"),
        Browser(bundleIdentifier: "company.thebrowser.dia", name: "Dia"),
        Browser(bundleIdentifier: "company.thebrowser.Browser", name: "Arc"),
        Browser(bundleIdentifier: "com.brave.Browser", name: "Brave"),
        Browser(bundleIdentifier: "com.microsoft.edgemac", name: "Microsoft Edge"),
        Browser(bundleIdentifier: "com.vivaldi.Vivaldi", name: "Vivaldi"),
    ]

    private static let interval: TimeInterval = 2
    private static let notPermitted = -1743

    /// Called with a browser's name the first time macOS refuses to let Odak script it.
    var onPermissionDenied: ((String) -> Void)?

    private var domains: [String] = []
    private var timer: Timer?
    private var denied = Set<String>()

    func start(domains: [String]) {
        stop()
        guard !domains.isEmpty else { return }
        self.domains = domains
        sweep()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sweep()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        domains.removeAll()
        denied.removeAll()
    }

    private func sweep() {
        for browser in Self.browsers where !denied.contains(browser.bundleIdentifier) && isRunning(browser) {
            for tab in blockedTabs(in: browser) {
                redirect(tab, in: browser)
            }
        }
    }

    // Scripting a browser that isn't running would launch it.
    private func isRunning(_ browser: Browser) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleIdentifier).isEmpty
    }

    private struct BlockedTab {
        let windowID: Int32
        let index: Int
        let domain: String
    }

    private func blockedTabs(in browser: Browser) -> [BlockedTab] {
        let source = """
        with timeout of 2 seconds
            tell application id "\(browser.bundleIdentifier)"
                set found to {}
                repeat with w in windows
                    try
                        set end of found to {id of w, URL of tabs of w}
                    end try
                end repeat
                return found
            end tell
        end timeout
        """
        guard let windows = run(source, for: browser), windows.numberOfItems > 0 else { return [] }

        var tabs: [BlockedTab] = []
        for windowIndex in 1...windows.numberOfItems {
            guard let window = windows.atIndex(windowIndex), window.numberOfItems == 2,
                  let windowID = window.atIndex(1)?.int32Value,
                  let urls = window.atIndex(2), urls.numberOfItems > 0 else { continue }
            for tabIndex in 1...urls.numberOfItems {
                guard let url = urls.atIndex(tabIndex)?.stringValue,
                      let domain = DomainParser.blockedDomain(forURL: url, in: domains) else { continue }
                tabs.append(BlockedTab(windowID: windowID, index: tabIndex, domain: domain))
            }
        }
        return tabs
    }

    private func redirect(_ tab: BlockedTab, in browser: Browser) {
        guard let page = Self.blockedPage(for: tab.domain) else { return }
        let source = """
        with timeout of 2 seconds
            tell application id "\(browser.bundleIdentifier)" to set URL of tab \(tab.index) of window id \(tab.windowID) to "\(page)"
        end timeout
        """
        _ = run(source, for: browser)
    }

    /// The bundled "blocked" page, with the domain in the fragment so the page can name it.
    nonisolated static func blockedPage(for domain: String, bundle: Bundle = .main) -> String? {
        guard let file = bundle.url(forResource: "blocked", withExtension: "html"),
              var components = URLComponents(url: file, resolvingAgainstBaseURL: false) else { return nil }
        components.fragment = domain
        return components.string
    }

    private func run(_ source: String, for browser: Browser) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let number = error?[NSAppleScript.errorNumber] as? Int, number == Self.notPermitted {
            denied.insert(browser.bundleIdentifier)
            onPermissionDenied?(browser.name)
        }
        return error == nil ? result : nil
    }
}
