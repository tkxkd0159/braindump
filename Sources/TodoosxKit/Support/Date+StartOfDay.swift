import Foundation

extension Date {
    public func startOfLocalDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
