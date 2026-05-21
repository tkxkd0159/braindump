import Foundation

public enum TodoError: Error, Equatable {
    case top3Full
    case scheduleConflict
    case scheduleOutOfRange
}
