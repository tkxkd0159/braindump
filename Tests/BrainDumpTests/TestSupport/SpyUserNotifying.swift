import Foundation
@testable import BrainDumpKit

/// In-memory `UserNotifying` for tests: records adds/removes and lets a test
/// drive the authorization outcome. `pending` mirrors what `add`/`removePending`
/// would leave registered with the system.
@MainActor
final class SpyUserNotifying: UserNotifying {
    var status: NotificationAuthorization = .authorized
    var grantOnRequest = true
    private(set) var requestCount = 0
    private(set) var added: [PlannedNotification] = []
    private(set) var removed: [String] = []
    var pending: [String] = []

    func authorizationStatus() async -> NotificationAuthorization { status }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func add(_ n: PlannedNotification) async {
        added.append(n)
        if !pending.contains(n.id) { pending.append(n.id) }
    }

    func pendingIdentifiers() async -> [String] { pending }

    func removePending(ids: [String]) async {
        removed.append(contentsOf: ids)
        pending.removeAll { ids.contains($0) }
    }
}
