import Foundation
import CoreTransferable

public struct TaskItemDragPayload: Codable, Transferable {
    public let id: UUID

    public init(id: UUID) {
        self.id = id
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
