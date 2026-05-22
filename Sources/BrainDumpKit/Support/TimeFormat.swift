import Foundation

public enum TimeFormat {
    public static func clock(minute: Int) -> String {
        let m = ((minute % (24 * 60)) + 24 * 60) % (24 * 60)
        let hour24 = m / 60
        let minute = m % 60
        let displayHour: Int = {
            if hour24 == 0 || hour24 == 12 { return 12 }
            return hour24 % 12
        }()
        let suffix = hour24 < 12 ? "AM" : "PM"
        if minute == 0 {
            return "\(displayHour):00 \(suffix)"
        }
        return String(format: "%d:%02d %@", displayHour, minute, suffix)
    }

    public static func clockEndOfDay(minute: Int) -> String {
        if minute == 24 * 60 { return "12:00 AM" }
        return clock(minute: minute)
    }

    public static func range(startMinute: Int, durationMinutes: Int) -> String {
        let end = startMinute + durationMinutes
        return "\(clock(minute: startMinute)) — \(clockEndOfDay(minute: end))"
    }
}
