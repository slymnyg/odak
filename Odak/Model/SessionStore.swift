import Foundation
import Observation

@Observable
@MainActor
final class SessionStore {
    private(set) var sessions: [Session]
    private let file: JSONFile<[Session]>

    init(file: JSONFile<[Session]> = JSONFile(fileName: "sessions.json")) {
        self.file = file
        sessions = file.load() ?? []
    }

    func record(_ session: Session) {
        sessions.append(session)
        file.save(sessions)
    }
}
