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

    public func restore(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: BackupSnapshot
        do {
            snapshot = try decoder.decode(BackupSnapshot.self, from: data)
        } catch {
            throw BackupError.malformed
        }
        guard snapshot.version == Self.currentVersion else {
            throw BackupError.unsupportedVersion(snapshot.version)
        }
        deleteAll()
        apply(snapshot)
        try context.save()
    }

    private func deleteAll() {
        for e in (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? [] { context.delete(e) }
        for i in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] { context.delete(i) }
        for d in (try? context.fetch(FetchDescriptor<Day>())) ?? [] { context.delete(d) }
    }

    private func apply(_ snapshot: BackupSnapshot) {
        for dto in snapshot.days {
            let day = Day(date: dto.date)
            context.insert(day)
            day.top3ItemIDs = dto.top3ItemIDs

            var itemsByID: [UUID: TaskItem] = [:]
            for itemDTO in dto.items {
                let item = makeItem(itemDTO)
                item.day = day
                context.insert(item)
                itemsByID[itemDTO.id] = item
            }
            for entryDTO in dto.entries {
                let entry = ScheduleEntry(
                    startMinute: entryDTO.startMinute,
                    durationMinutes: entryDTO.durationMinutes,
                    colorIndex: entryDTO.colorIndex,
                    item: entryDTO.itemID.flatMap { itemsByID[$0] },
                    day: day)
                entry.id = entryDTO.id
                entry.isCompleted = entryDTO.isCompleted
                entry.completedAt = entryDTO.completedAt
                context.insert(entry)
            }
        }
        for itemDTO in snapshot.backlogItems {
            context.insert(makeItem(itemDTO))
        }
    }

    private func makeItem(_ dto: ItemDTO) -> TaskItem {
        let item = TaskItem(
            title: dto.title, createdAt: dto.createdAt, notes: dto.notes,
            tags: dto.tags, isBacklog: dto.isBacklog)
        item.id = dto.id
        return item
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
