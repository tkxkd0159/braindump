import Foundation
import SwiftData

public enum BackupError: Error, Equatable {
    case unsupportedVersion(Int)
    case malformed
}

public struct ItemDTO: Codable, Equatable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var notes: String
    public var tags: [String]
    public var isBacklog: Bool
}

public struct EntryDTO: Codable, Equatable {
    public var id: UUID
    public var startMinute: Int
    public var durationMinutes: Int
    public var isCompleted: Bool
    public var completedAt: Date?
    public var colorIndex: Int
    public var itemID: UUID?
}

public struct DayDTO: Codable, Equatable {
    public var date: Date
    public var top3ItemIDs: [UUID]
    public var items: [ItemDTO]
    public var entries: [EntryDTO]
}

public struct BackupSnapshot: Codable, Equatable {
    public var version: Int
    public var days: [DayDTO]
    public var backlogItems: [ItemDTO]
}

@MainActor
public final class BackupService {
    public static let currentVersion = 1
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func exportData() throws -> Data {
        let snapshot = makeSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func makeSnapshot() -> BackupSnapshot {
        let allDays = (try? context.fetch(
            FetchDescriptor<Day>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let days = allDays.map { day in
            DayDTO(
                date: day.date,
                top3ItemIDs: day.top3ItemIDs,
                items: day.items.filter { !$0.isBacklog }.map(Self.itemDTO),
                entries: day.schedule.map { e in
                    EntryDTO(
                        id: e.id, startMinute: e.startMinute,
                        durationMinutes: e.durationMinutes, isCompleted: e.isCompleted,
                        completedAt: e.completedAt, colorIndex: e.colorIndex, itemID: e.item?.id)
                })
        }
        let backlogItems = ((try? context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isBacklog }))) ?? [])
            .map(Self.itemDTO)
        return BackupSnapshot(version: Self.currentVersion, days: days, backlogItems: backlogItems)
    }

    private static func itemDTO(_ i: TaskItem) -> ItemDTO {
        ItemDTO(
            id: i.id, title: i.title, createdAt: i.createdAt,
            notes: i.notes, tags: i.tags, isBacklog: i.isBacklog)
    }
}
