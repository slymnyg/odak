import AppKit
import SwiftUI

@MainActor
final class PlannerWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        let window = self.window ?? makeWindow(model: model)
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Puts the planner above every other window, on whichever Space is showing, and keeps it
    /// there until `settle()`. For the one moment a day Odak asks for attention.
    func showOnTop(model: AppModel) {
        let window = self.window ?? makeWindow(model: model)
        self.window = window
        NSApp.unhide(nil)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.level = .floating
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Back to an ordinary window.
    func settle() {
        window?.level = .normal
        window?.collectionBehavior.remove(.moveToActiveSpace)
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 690),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Odak"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PlannerView().environment(model))
        window.setContentSize(NSSize(width: 1060, height: 690))
        window.center()
        window.setFrameAutosaveName("PlannerWindow")
        return window
    }
}
