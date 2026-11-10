import Foundation

/// The page a blocked tab lands on. Besides naming the site, it shows what the session is for and
/// what is still planned today, so the detour costs a look at the work it was avoiding.
enum BlockedPage {
    struct Item: Encodable, Equatable {
        enum State: String, Encodable {
            case done, now, next
        }

        let title: String
        let time: String
        let lane: String
        let state: State
    }

    struct Context: Encodable, Equatable {
        var intention = ""
        var tasks: [Item] = []
    }

    static let placeholder = "/*ODAK_DATA*/null"

    /// Today's plan as the page shows it: what is over, what is on now and what is still to come.
    static func context(intention: String, tasks: [PlannedTask], now: Date) -> Context {
        Context(
            intention: intention.trimmingCharacters(in: .whitespacesAndNewlines),
            tasks: tasks.sorted { $0.start < $1.start }.map { task in
                Item(
                    title: task.title,
                    time: task.start.formatted(date: .omitted, time: .shortened),
                    lane: task.lane.rawValue,
                    state: task.end <= now ? .done : (task.start <= now ? .now : .next)
                )
            }
        )
    }

    /// The template with the context written into its script. The JSON is made safe to sit inside
    /// a `<script>` element; the page only ever inserts it as text.
    static func html(template: String, context: Context) -> String {
        guard let data = try? JSONEncoder().encode(context) else { return template }
        let json = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return template.replacingOccurrences(of: placeholder, with: json)
    }
}
