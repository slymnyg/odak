import Foundation

enum HelperInstaller {
    static let helperPath = "/Library/PrivilegedHelperTools/app.odak.block"
    /// sudo skips files in sudoers.d whose names contain a dot, so this one uses an underscore.
    static let sudoersPath = "/etc/sudoers.d/app_odak"

    enum Failure: LocalizedError {
        case cancelled
        case missingResource
        case unsupportedUserName
        case scriptFailed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled:
                String(localized: "The administrator password dialog was cancelled.")
            case .missingResource:
                String(localized: "The helper script is missing from the app bundle.")
            case .unsupportedUserName:
                String(localized: "Your account name contains characters that can't be used in a sudoers rule.")
            case .scriptFailed(let message):
                String(localized: "The helper could not be changed: \(message)")
            }
        }
    }

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
    }

    @MainActor
    static func install() throws {
        guard let source = Bundle.main.url(forResource: "odak-block", withExtension: nil) else {
            throw Failure.missingResource
        }
        let user = NSUserName()
        guard user.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            throw Failure.unsupportedUserName
        }
        let rule = "\(user) ALL=(root) NOPASSWD: \(helperPath)"
        let command = [
            "set -e",
            "/bin/mkdir -p /Library/PrivilegedHelperTools /etc/sudoers.d",
            "/usr/sbin/chown root:wheel /Library/PrivilegedHelperTools",
            "/bin/chmod go-w /Library/PrivilegedHelperTools",
            "/usr/bin/install -o root -g wheel -m 755 \(shellQuoted(source.path)) \(shellQuoted(helperPath))",
            "rule_file=$(/usr/bin/mktemp)",
            "trap '/bin/rm -f \"$rule_file\"' EXIT",
            "/usr/bin/printf '%s\\n' \(shellQuoted(rule)) > \"$rule_file\"",
            "/usr/sbin/visudo -cf \"$rule_file\" > /dev/null",
            "/usr/bin/install -o root -g wheel -m 440 \"$rule_file\" \(shellQuoted(sudoersPath))",
        ].joined(separator: "; ")
        try runAsAdministrator(command, prompt: String(localized: "Odak needs your permission once to block websites during focus sessions."))
    }

    @MainActor
    static func uninstall() throws {
        let helper = shellQuoted(helperPath)
        let command = [
            "if [ -x \(helper) ]; then \(helper) off || true; fi",
            "/bin/rm -f \(helper) \(shellQuoted(sudoersPath))",
        ].joined(separator: "; ")
        try runAsAdministrator(command, prompt: String(localized: "Odak needs your permission to remove its website blocking helper."))
    }

    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    @MainActor
    private static func runAsAdministrator(_ command: String, prompt: String) throws {
        let source = "do shell script \(appleScriptQuoted(command)) with prompt \(appleScriptQuoted(prompt)) with administrator privileges"
        guard let script = NSAppleScript(source: source) else {
            throw Failure.scriptFailed(source)
        }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return }
        if errorInfo[NSAppleScript.errorNumber] as? Int == -128 {
            throw Failure.cancelled
        }
        throw Failure.scriptFailed(errorInfo[NSAppleScript.errorMessage] as? String ?? "")
    }
}
