import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(Preferences.Key.focusMinutes) private var focusMinutes = Preferences.Default.focusMinutes
    @AppStorage(Preferences.Key.shortBreakMinutes) private var shortBreakMinutes = Preferences.Default.shortBreakMinutes
    @AppStorage(Preferences.Key.longBreakMinutes) private var longBreakMinutes = Preferences.Default.longBreakMinutes
    @AppStorage(Preferences.Key.autoStartBreaks) private var autoStartBreaks = Preferences.Default.autoStartBreaks
    @AppStorage(Preferences.Key.playSound) private var playSound = Preferences.Default.playSound
    @AppStorage(Preferences.Key.showSeconds) private var showSeconds = Preferences.Default.showSeconds
    @AppStorage(Preferences.Key.showFocusScreen) private var showFocusScreen = Preferences.Default.showFocusScreen

    @AppStorage(Preferences.Key.trackActivity) private var trackActivity = Preferences.Default.trackActivity
    @AppStorage(Preferences.Key.activityFolder) private var activityFolder = Preferences.Default.activityFolder
    @Environment(AppModel.self) private var model

    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String? = nil

    var body: some View {
        Form {
            Section("Timer") {
                Stepper("Focus: \(focusMinutes) min", value: $focusMinutes, in: Preferences.focusRange)
                Stepper("Short break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: Preferences.breakRange)
                Stepper("Long break: \(longBreakMinutes) min", value: $longBreakMinutes, in: Preferences.breakRange)
                Toggle("Start breaks automatically", isOn: $autoStartBreaks)
                Text("A long break follows every \(Preferences.longBreakInterval) focus sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Focus Mode") {
                Toggle("Full-screen focus screen", isOn: $showFocusScreen)
                Text("Covers the main display with a dark screen showing only the countdown. Press Esc to return to the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu Bar & Sound") {
                Toggle("Show seconds in menu bar", isOn: $showSeconds)
                Toggle("Play sound when a session ends", isOn: $playSound)
            }

            Section("Projects") {
                Toggle("Track time per project", isOn: $trackActivity)
                LabeledContent("Projects folder") {
                    HStack {
                        Text(verbatim: (activityFolder as NSString).abbreviatingWithTildeInPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…", action: chooseActivityFolder)
                    }
                }
                Text("Each git repository in this folder is a project. Odak notes when its files change and reads your commits for the week in review. Nothing leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: trackActivity) { model.startActivityTracking() }
            .onChange(of: activityFolder) { model.startActivityTracking() }

            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLogin)
                if loginStatus == .requiresApproval {
                    HStack {
                        Text("Allow Odak in System Settings → Login Items.")
                            .font(.caption)
                        Spacer()
                        Button("Open Login Items") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    }
                }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func chooseActivityFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: activityFolder, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            activityFolder = url.path
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { loginStatus == .enabled || loginStatus == .requiresApproval },
            set: { setLaunchAtLogin($0) }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        loginStatus = SMAppService.mainApp.status
    }
}
