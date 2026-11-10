import Foundation

enum Preferences {
    enum Key {
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let autoStartBreaks = "autoStartBreaks"
        static let playSound = "playSound"
        static let showSeconds = "showSecondsInMenuBar"
        static let showFocusScreen = "showFocusScreen"
        static let blockDistractions = "blockDistractions"
        static let blockedSites = "blockedSites"
        static let blockedApps = "blockedApps"
        static let trackActivity = "trackActivity"
        static let activityFolder = "activityFolder"
        static let dataFolder = "dataFolder"
        static let planDay = "planDay"
        static let planDayMinutes = "planDayMinutes"
        static let taskReminderLead = "taskReminderLead"
        static let lastPlannedDay = "lastPlannedDay"
    }

    enum Default {
        static let focusMinutes = 25
        static let shortBreakMinutes = 5
        static let longBreakMinutes = 15
        static let autoStartBreaks = false
        static let playSound = true
        static let showSeconds = true
        static let showFocusScreen = true
        static let blockDistractions = true
        static let trackActivity = true
        static let activityFolder = NSHomeDirectory() + "/Development"
        static let planDay = true
        static let planDayMinutes = 9 * 60
        static let taskReminderLead = 5
        static let blockedSites = [
            "youtube.com", "youtu.be", "x.com", "twitter.com", "reddit.com", "instagram.com",
        ].joined(separator: "\n")
    }

    static let focusRange = 1...600
    static let breakRange = 1...120
    static let durationPresets = [15, 25, 45, 60, 90]
    static let longBreakInterval = 4

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.focusMinutes: Default.focusMinutes,
            Key.shortBreakMinutes: Default.shortBreakMinutes,
            Key.longBreakMinutes: Default.longBreakMinutes,
            Key.autoStartBreaks: Default.autoStartBreaks,
            Key.playSound: Default.playSound,
            Key.showSeconds: Default.showSeconds,
            Key.showFocusScreen: Default.showFocusScreen,
            Key.blockDistractions: Default.blockDistractions,
            Key.blockedSites: Default.blockedSites,
            Key.trackActivity: Default.trackActivity,
            Key.activityFolder: Default.activityFolder,
            Key.planDay: Default.planDay,
            Key.planDayMinutes: Default.planDayMinutes,
            Key.taskReminderLead: Default.taskReminderLead,
        ])
    }

    static var focusMinutes: Int { clamped(defaults.integer(forKey: Key.focusMinutes), to: focusRange) }
    static var shortBreakMinutes: Int { clamped(defaults.integer(forKey: Key.shortBreakMinutes), to: breakRange) }
    static var longBreakMinutes: Int { clamped(defaults.integer(forKey: Key.longBreakMinutes), to: breakRange) }
    static var autoStartBreaks: Bool { defaults.bool(forKey: Key.autoStartBreaks) }
    static var playSound: Bool { defaults.bool(forKey: Key.playSound) }
    static var showFocusScreen: Bool { defaults.bool(forKey: Key.showFocusScreen) }
    static var blockDistractions: Bool { defaults.bool(forKey: Key.blockDistractions) }
    static var trackActivity: Bool { defaults.bool(forKey: Key.trackActivity) }

    /// The folder whose repositories count as projects.
    static var activityFolder: URL {
        URL(fileURLWithPath: defaults.string(forKey: Key.activityFolder) ?? Default.activityFolder, isDirectory: true)
    }

    /// Whether Odak invites you to plan the day, and from which minute of the day.
    static var planDay: Bool { defaults.bool(forKey: Key.planDay) }
    static var planDayMinutes: Int { clamped(defaults.integer(forKey: Key.planDayMinutes), to: 0...(24 * 60 - 1)) }

    /// Minutes before a task starts at which to remind; `noReminder` turns reminders off.
    static var taskReminderLead: Int { defaults.integer(forKey: Key.taskReminderLead) }
    static let noReminder = -1
    static let reminderLeads = [noReminder, 0, 5, 10, 15]

    /// Day key of the last day that was planned or waved off, so the invitation comes once a day.
    static var lastPlannedDay: String {
        get { defaults.string(forKey: Key.lastPlannedDay) ?? "" }
        set { defaults.set(newValue, forKey: Key.lastPlannedDay) }
    }

    /// A folder chosen to hold plans, history and project time, typically a synced one.
    /// `nil` keeps them in Application Support.
    static var dataFolder: URL? {
        get {
            guard let path = defaults.string(forKey: Key.dataFolder), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set { defaults.set(newValue?.path, forKey: Key.dataFolder) }
    }

    static var blockedSites: String { defaults.string(forKey: Key.blockedSites) ?? "" }

    static var blockedApps: [BlockedApp] {
        BlockedApp.decodeList(from: defaults.data(forKey: Key.blockedApps) ?? Data())
    }

    static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static var defaults: UserDefaults { .standard }
}
