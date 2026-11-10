import CoreServices
import Foundation

/// Watches a folder tree and reports which projects had files change.
final class ActivityWatcher {
    private let root: URL
    private let onActivity: @MainActor (Set<String>) -> Void
    private let queue = DispatchQueue(label: "app.odak.activity-watcher", qos: .utility)
    private var resolver: ProjectResolver
    private var stream: FSEventStreamRef?

    init(root: URL, onActivity: @escaping @MainActor (Set<String>) -> Void) {
        self.root = root
        self.onActivity = onActivity
        resolver = ProjectResolver(root: root)
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info, let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }
            let watcher = Unmanaged<ActivityWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.handle(paths: paths, flags: Array(UnsafeBufferPointer(start: flags, count: count)))
        }
        let options = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            5,
            FSEventStreamCreateFlags(options)
        ) else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    // Runs on `queue`.
    private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
        let wanted = FSEventStreamEventFlags(
            kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemModified
                | kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemRemoved
        )
        let isFile = FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)

        var projects = Set<String>()
        for (path, flag) in zip(paths, flags) where flag & isFile != 0 && flag & wanted != 0 {
            if let project = resolver.project(forPath: path) {
                projects.insert(project)
            }
        }
        guard !projects.isEmpty else { return }
        let onActivity = onActivity
        Task { @MainActor in
            onActivity(projects)
        }
    }
}
