import Foundation

final class SiteBlocker: Sendable {
    enum Failure: LocalizedError {
        case notAuthorized
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                String(localized: "Odak isn't allowed to run its helper. Reinstall it in Settings → Blocking.")
            case .commandFailed(let message):
                String(localized: "Website blocking failed: \(message)")
            }
        }
    }

    private let queue = DispatchQueue(label: "app.odak.site-blocker")

    func block(_ domains: [String]) async throws {
        try await run(["on"] + domains)
    }

    func unblock() async throws {
        try await run(["off"])
    }

    func unblockImmediately() {
        queue.sync {
            _ = try? Self.execute(["off"])
        }
    }

    private func run(_ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try Self.execute(arguments)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func execute(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", HelperInstaller.helperPath] + arguments
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains("password is required") {
                throw Failure.notAuthorized
            }
            throw Failure.commandFailed(message)
        }
    }
}
