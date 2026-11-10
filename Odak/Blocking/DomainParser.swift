import Foundation

enum DomainParser {
    static let mirrorPrefixes = ["www.", "m.", "mobile."]
    static let maxLength = 253

    static func parse(_ text: String) -> [String] {
        var seen = Set<String>()
        return text
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .compactMap { normalize(String($0)) }
            .filter { seen.insert($0).inserted }
    }

    static func normalize(_ input: String) -> String? {
        var host = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let schemeEnd = host.range(of: "://") {
            host = String(host[schemeEnd.upperBound...])
        }
        if let pathStart = host.firstIndex(where: { "/?#".contains($0) }) {
            host = String(host[..<pathStart])
        }
        if let userInfoEnd = host.lastIndex(of: "@") {
            host = String(host[host.index(after: userInfoEnd)...])
        }
        if let portStart = host.firstIndex(of: ":") {
            host = String(host[..<portStart])
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        if host.hasPrefix("*.") {
            host.removeFirst(2)
        }
        if let prefix = mirrorPrefixes.first(where: { host.hasPrefix($0) }) {
            let remainder = String(host.dropFirst(prefix.count))
            if remainder.contains(".") {
                host = remainder
            }
        }
        return isValid(host) ? host : nil
    }

    static func isValid(_ host: String) -> Bool {
        guard host.count <= maxLength else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, let topLevel = labels.last, !topLevel.allSatisfy(\.isNumber) else {
            return false
        }
        return labels.allSatisfy(isValidLabel)
    }

    /// The blocked domain a web address falls under, if any. Subdomains count: `music.youtube.com`
    /// is covered by `youtube.com`.
    static func blockedDomain(forURL address: String, in domains: [String]) -> String? {
        guard let components = URLComponents(string: address),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              var host = components.host?.lowercased() else { return nil }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        return domains.first { host == $0 || host.hasSuffix("." + $0) }
    }

    static func expand(_ domains: [String]) -> [String] {
        domains
            .flatMap { domain in [domain] + mirrorPrefixes.map { $0 + domain } }
            .filter { $0.count <= maxLength }
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        guard (1...63).contains(label.count), label.first != "-", label.last != "-" else { return false }
        return label.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-")
        }
    }
}
