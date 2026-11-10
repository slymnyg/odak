import AppKit
import SwiftUI

@MainActor
final class FocusScreenController {
    private var window: NSWindow?
    private var keyMonitor: Any?
    private var previousPresentationOptions: NSApplication.PresentationOptions = []
    private weak var model: AppModel?

    func show(model: AppModel) {
        guard self.window == nil, let screen = NSScreen.main else { return }
        self.model = model

        let window = BorderlessKeyWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .black
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: FocusScreenView().environment(model))
        window.setFrame(screen.frame, display: true)

        previousPresentationOptions = NSApp.presentationOptions
        NSApp.activate()
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        window.makeKeyAndOrderFront(nil)
        self.window = window
        installEscapeMonitor()
    }

    func hide() {
        guard let window else { return }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        NSApp.presentationOptions = previousPresentationOptions
        window.orderOut(nil)
        self.window = nil
    }

    private func installEscapeMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == escapeKeyCode else { return event }
            // Local monitors run on the main thread. Only a Sendable Bool leaves the isolated closure.
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self, let window = self.window, event.window === window else { return false }
                self.model?.hideFocusScreen()
                return true
            }
            return handled ? nil : event
        }
    }
}

private let escapeKeyCode: UInt16 = 53

private final class BorderlessKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
