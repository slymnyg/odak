import CoreServices
import Foundation

/// Calls back on the main actor, a moment after anything under the watched folders changes.
final class FolderWatcher {
    private let folders: [URL]
    private let onChange: @MainActor () -> Void
    private let queue = DispatchQueue(label: "app.odak.folder-watcher", qos: .utility)
    private var stream: FSEventStreamRef?

    init(folders: [URL], onChange: @escaping @MainActor () -> Void) {
        self.folders = folders
        self.onChange = onChange
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
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let onChange = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange
            Task { @MainActor in
                onChange()
            }
        }
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            folders.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
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
}
