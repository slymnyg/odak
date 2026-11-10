import Foundation

/// Maps a changed file to the project it belongs to: the nearest enclosing git repository,
/// named by its path under the watched folder (`github.com/owner/repo`).
struct ProjectResolver {
    /// Folders whose contents are produced by tools, not by the person working.
    static let noiseFolders: Set<String> = [
        ".git", "node_modules", "build", "DerivedData", ".build", ".swiftpm", ".dart_tool", "Pods",
        ".gradle", "dist", ".next", ".turbo", ".expo", "target", "xcuserdata", "__pycache__",
        ".venv", "venv", ".cache", "coverage", ".idea",
    ]

    let root: URL
    private let rootComponents: [String]
    private var projectByFolder: [String: String?] = [:]

    init(root: URL) {
        self.root = root.standardizedFileURL
        rootComponents = self.root.pathComponents
    }

    static func isNoise(_ components: [String]) -> Bool {
        guard let file = components.last else { return true }
        if file == ".DS_Store" || file.hasSuffix(".log") || file.hasSuffix("~") { return true }
        return components.contains(where: noiseFolders.contains)
    }

    /// For a linked worktree, whose `.git` is a file pointing into `<main>/.git/worktrees/<name>`,
    /// the main repository's folder. `nil` for an ordinary repository.
    static func mainRepository(ofWorktreeMarker marker: URL) -> URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: marker.path, isDirectory: &isDirectory), !isDirectory.boolValue,
              let text = try? String(contentsOf: marker, encoding: .utf8),
              let line = text.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("gitdir:") }),
              let range = line.range(of: "/.git/worktrees/") else { return nil }
        let path = line[line.index(line.startIndex, offsetBy: "gitdir:".count)..<range.lowerBound]
            .trimmingCharacters(in: .whitespaces)
        return path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true)
    }

    /// The file's path below the root, or `nil` when it lies outside.
    func relativeComponents(ofPath path: String) -> [String]? {
        let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        guard components.count > rootComponents.count, Array(components.prefix(rootComponents.count)) == rootComponents else {
            return nil
        }
        return Array(components.dropFirst(rootComponents.count))
    }

    mutating func project(forPath path: String, fileManager: FileManager = .default) -> String? {
        guard let components = relativeComponents(ofPath: path), !Self.isNoise(components) else { return nil }
        let folders = Array(components.dropLast())
        guard !folders.isEmpty else { return nil }
        let key = folders.joined(separator: "/")
        if let cached = projectByFolder[key] { return cached }

        var found: String?
        for depth in stride(from: folders.count, to: 0, by: -1) {
            let candidate = folders.prefix(depth).joined(separator: "/")
            let marker = root.appending(path: candidate).appending(path: ".git")
            if fileManager.fileExists(atPath: marker.path) {
                // A linked worktree is the same project as the repository it was cut from.
                found = Self.mainRepository(ofWorktreeMarker: marker)
                    .flatMap { relativeComponents(ofPath: $0.appending(path: "x").path) }
                    .map { $0.dropLast().joined(separator: "/") } ?? candidate
                break
            }
        }
        // Work that isn't in a repository yet is filed under its top folders.
        let project = found ?? folders.prefix(2).joined(separator: "/")
        projectByFolder[key] = project
        return project
    }
}
