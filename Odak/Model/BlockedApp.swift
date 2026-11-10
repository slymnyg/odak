import Foundation

struct BlockedApp: Codable, Hashable, Identifiable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }

    static func decodeList(from data: Data) -> [BlockedApp] {
        (try? JSONDecoder().decode([BlockedApp].self, from: data)) ?? []
    }

    static func encodeList(_ apps: [BlockedApp]) -> Data {
        (try? JSONEncoder().encode(apps)) ?? Data()
    }
}
