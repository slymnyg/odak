import Foundation

enum Countdown {
    static func string(for interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func minutesRemaining(for interval: TimeInterval) -> Int {
        max(0, Int((interval / 60).rounded(.up)))
    }
}
