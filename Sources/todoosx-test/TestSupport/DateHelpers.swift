import Foundation

enum TestDate {
    static func at(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
        DateComponents(
            calendar: .current,
            year: y,
            month: m,
            day: d,
            hour: hour,
            minute: minute
        ).date!
    }
}
