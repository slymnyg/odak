import Foundation
import Observation

/// Finished focus sessions. Each Mac appends to its own file; `sessions` is all of them together.
@Observable
@MainActor
final class SessionStore {
    private(set) var sessions: [Session] = []
    @ObservationIgnored private var own: [Session]
    @ObservationIgnored private var folder: URL
    @ObservationIgnored private let device: String

    init(folder: URL, device: String) {
        self.folder = folder
        self.device = device
        own = JSONFile<[Session]>(url: folder.appending(path: device + ".json")).load() ?? []
        reload()
    }

    func record(_ session: Session) {
        own.append(session)
        ownFile.save(own)
        sessions = Self.merged(sessions + [session])
    }

    /// Reads the other Macs' files again.
    func reload() {
        let others = Storage.jsonFiles(in: folder)
            .filter { $0 != ownFile.url && $0.lastPathComponent != ownFile.url.lastPathComponent }
            .flatMap { JSONFile<[Session]>(url: $0).load() ?? [] }
        let fresh = Self.merged(own + others)
        if fresh != sessions {
            sessions = fresh
        }
    }

    /// Moves to another folder, bringing this Mac's history along.
    func relocate(to newFolder: URL) {
        guard newFolder != folder else { return }
        folder = newFolder
        own = Self.merged(own + (ownFile.load() ?? []))
        if !own.isEmpty {
            ownFile.save(own)
        }
        reload()
    }

    private var ownFile: JSONFile<[Session]> {
        JSONFile(url: folder.appending(path: device + ".json"))
    }

    private static func merged(_ sessions: [Session]) -> [Session] {
        var seen = Set<Session.ID>()
        return sessions
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.start, $0.id.uuidString) < ($1.start, $1.id.uuidString) }
    }
}
