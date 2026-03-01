import Foundation

public enum DurationFormatter {
    public static func string(since startedAt: Date, now: Date = Date()) -> String {
        let interval = max(0, Int(now.timeIntervalSince(startedAt)))
        let minutes = interval / 60
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            let remainingHours = hours % 24
            return remainingHours > 0 ? "\(days)d \(remainingHours)h" : "\(days)d"
        }

        if hours > 0 {
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }

        return "\(max(1, minutes))m"
    }
}
