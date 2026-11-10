import Foundation
import SystemConfiguration

/// Where Odak keeps what it records, and under which name this Mac writes.
///
/// The layout is made to be shared through a synced folder such as iCloud Drive without two Macs
/// writing the same file: plans are one file per day, while focus history and project time are one
/// file per Mac and are merged when read.
struct Storage: Equatable {
    let root: URL
    let device: String

    var plans: URL { root.appending(path: "plans", directoryHint: .isDirectory) }
    var sessions: URL { root.appending(path: "sessions", directoryHint: .isDirectory) }
    var activity: URL { root.appending(path: "activity", directoryHint: .isDirectory) }

    static var localRoot: URL {
        URL.applicationSupportDirectory.appending(path: "Odak", directoryHint: .isDirectory)
    }

    /// The Odak folder in iCloud Drive, or `nil` when iCloud Drive is off on this Mac.
    static var iCloudRoot: URL? {
        let drive = URL.libraryDirectory.appending(path: "Mobile Documents/com~apple~CloudDocs", directoryHint: .isDirectory)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: drive.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
        return drive.appending(path: "Odak", directoryHint: .isDirectory)
    }

    /// The chosen data folder, or the local one when none is chosen or the chosen one is out of
    /// reach (iCloud signed out, a drive not mounted). Nothing is ever written to a guessed path.
    static func standard() -> Storage {
        // The test host launches the whole app; it must not read or write real data.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let scratch = FileManager.default.temporaryDirectory
                .appending(path: "odak-tests-\(ProcessInfo.processInfo.processIdentifier)", directoryHint: .isDirectory)
            return Storage(root: scratch, device: "tests")
        }
        let local = Storage(root: localRoot, device: deviceID)
        local.adoptLegacyFiles()
        guard let chosen = Preferences.dataFolder, isReachable(chosen) else { return local }
        return Storage(root: chosen, device: deviceID)
    }

    /// True when a folder was chosen but Odak had to fall back to the local one.
    static var isFallingBack: Bool {
        guard let chosen = Preferences.dataFolder else { return false }
        return !isReachable(chosen)
    }

    static func isReachable(_ folder: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let parent = folder.deletingLastPathComponent().path
        guard FileManager.default.fileExists(atPath: parent, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            return true
        } catch CocoaError.fileWriteFileExists {
            return FileManager.default.isWritableFile(atPath: folder.path)
        } catch {
            return false
        }
    }

    /// A stable, readable name for this Mac's own files, such as `MacBook-Pro-3f9a2c`.
    static var deviceID: String {
        let key = "deviceID"
        if let saved = UserDefaults.standard.string(forKey: key), !saved.isEmpty { return saved }
        let name = (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? "Mac"
        let id = fileSafe(name) + "-" + UUID().uuidString.prefix(6).lowercased()
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static func fileSafe(_ name: String) -> String {
        // Folding leaves the Turkish dotless ı alone, so it is mapped by hand.
        let folded = name.replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
        let cleaned = String(folded.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" })
        let parts = cleaned.split(separator: "-", omittingEmptySubsequences: true)
        return parts.isEmpty ? "Mac" : parts.joined(separator: "-")
    }

    /// Versions before the shared layout kept everything in three files. Their contents are copied
    /// into the new layout once; the old files are left where they are.
    func adoptLegacyFiles() {
        let manager = FileManager.default
        if !manager.fileExists(atPath: plans.path),
           let tasks = JSONFile<[PlannedTask]>(url: root.appending(path: "plans.json")).load() {
            PlanFiles.write(tasks, to: plans)
        }
        if !manager.fileExists(atPath: sessions.path),
           let old = JSONFile<[Session]>(url: root.appending(path: "sessions.json")).load() {
            JSONFile<[Session]>(url: sessions.appending(path: device + ".json")).save(old)
        }
        if !manager.fileExists(atPath: activity.path),
           let old = JSONFile<[String: [String: [Int]]]>(url: root.appending(path: "activity.json")).load() {
            JSONFile<[String: [String: [Int]]]>(url: activity.appending(path: device + ".json")).save(old)
        }
    }

    /// The JSON files directly inside `folder`, by name.
    static func jsonFiles(in folder: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

/// Plans on disk: one file per day, named `2026-11-10.json`.
enum PlanFiles {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func isDayFile(_ url: URL) -> Bool {
        url.deletingPathExtension().lastPathComponent.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil
    }

    /// Every task in the folder. Copies a sync service leaves beside a day file after a conflict
    /// are not day files and are skipped; a task that shows up twice is taken once.
    static func load(from folder: URL) -> [PlannedTask] {
        var seen = Set<PlannedTask.ID>()
        var tasks: [PlannedTask] = []
        for url in Storage.jsonFiles(in: folder) where isDayFile(url) {
            for task in JSONFile<[PlannedTask]>(url: url).load() ?? [] where seen.insert(task.id).inserted {
                tasks.append(task)
            }
        }
        return tasks
    }

    /// Rewrites the files of `days`, or of every day that has a task when `days` is `nil`.
    /// A day that lost its last task keeps an empty file, so the removal reaches other Macs.
    static func write(_ tasks: [PlannedTask], to folder: URL, days: Set<String>? = nil, calendar: Calendar = .current) {
        let byDay = Dictionary(grouping: tasks) { key(for: $0.start, calendar: calendar) }
        for day in days ?? Set(byDay.keys) {
            let file = JSONFile<[PlannedTask]>(url: folder.appending(path: day + ".json"))
            let dayTasks = (byDay[day] ?? []).sorted { ($0.start, $0.id.uuidString) < ($1.start, $1.id.uuidString) }
            if dayTasks.isEmpty && !FileManager.default.fileExists(atPath: file.url.path) { continue }
            file.save(dayTasks)
        }
    }
}
