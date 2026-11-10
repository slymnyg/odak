import Foundation

struct Commit: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let subject: String
}

/// Reads what was committed in the repositories under a folder. Read-only: it only runs `git log`.
enum GitHistory {
    private static let fieldSeparator = "\u{1F}"

    /// A real git binary. `/usr/bin/git` is skipped on purpose: without developer tools it is a stub
    /// that pops up an install dialog.
    static var gitURL: URL? {
        [
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
        ]
        .first(where: FileManager.default.isExecutableFile(atPath:))
        .map(URL.init(fileURLWithPath:))
    }

    /// Repositories below `root`, as paths relative to it. Does not look inside a repository for more,
    /// and leaves out linked worktrees.
    static func repositories(under root: URL, maxDepth: Int = 4, fileManager: FileManager = .default) -> [String] {
        var found: [String] = []
        var queue: [(url: URL, path: [String])] = [(root, [])]
        while !queue.isEmpty {
            let (url, path) = queue.removeFirst()
            let marker = url.appending(path: ".git")
            if !path.isEmpty, fileManager.fileExists(atPath: marker.path) {
                // Linked worktrees share their main repository's history; listing them would count it twice.
                if ProjectResolver.mainRepository(ofWorktreeMarker: marker) == nil {
                    found.append(path.joined(separator: "/"))
                }
                continue
            }
            guard path.count < maxDepth,
                  let children = try? fileManager.contentsOfDirectory(
                      at: url,
                      includingPropertiesForKeys: [.isDirectoryKey],
                      options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { continue }
            for child in children where (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let name = child.lastPathComponent
                if !ProjectResolver.noiseFolders.contains(name) {
                    queue.append((child, path + [name]))
                }
            }
        }
        return found.sorted()
    }

    static func parse(_ output: String) -> [Commit] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.components(separatedBy: fieldSeparator)
            guard fields.count >= 3, let seconds = TimeInterval(fields[1]) else { return nil }
            return Commit(
                id: fields[0],
                date: Date(timeIntervalSince1970: seconds),
                subject: fields[2...].joined(separator: fieldSeparator)
            )
        }
    }

    /// The reader's own commits in each repository under `root` within the interval, newest first.
    static func commits(under root: URL, in interval: DateInterval) async -> [String: [Commit]] {
        await Task.detached(priority: .utility) {
            guard let git = gitURL else { return [:] }
            var result: [String: [Commit]] = [:]
            for repository in repositories(under: root) {
                let folder = root.appending(path: repository).path
                let email = run(git, ["-C", folder, "config", "user.email"])?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                var arguments = [
                    "-C", folder, "log", "--all", "--no-merges",
                    "--since=\(interval.start.ISO8601Format())", "--until=\(interval.end.ISO8601Format())",
                    "--format=%H%x1f%at%x1f%s",
                ]
                if !email.isEmpty {
                    arguments += ["--fixed-strings", "--author=\(email)"]
                }
                let commits = parse(run(git, arguments) ?? "").filter { interval.contains($0.date) }
                if !commits.isEmpty {
                    result[repository] = commits.sorted { $0.date > $1.date }
                }
            }
            return result
        }.value
    }

    private static func run(_ git: URL, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = git
        process.arguments = arguments
        process.environment = ["GIT_OPTIONAL_LOCKS": "0", "GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C", "HOME": NSHomeDirectory()]
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
