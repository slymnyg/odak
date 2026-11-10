import Foundation
import OSLog

struct JSONFile<Value: Codable> {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(fileName: String) {
        self.init(url: URL.applicationSupportDirectory
            .appending(path: "Odak", directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory))
    }

    func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            Logger.storage.error("Could not decode \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Self.encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            Logger.storage.error("Could not save \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension Logger {
    static let storage = Logger(subsystem: "app.odak.Odak", category: "storage")
}
