import Foundation
import Testing
@testable import BrainDumpKit

@MainActor
@Test func defaultModelIsUnavailableAndCannotCheck() {
    let model = AppUpdateModel()
    #expect(model.isUpdaterAvailable == false)
    #expect(model.canCheckForUpdates == false)
    #expect(model.shortVersion == "—")
    #expect(model.buildVersion == "—")
}

@MainActor
@Test func togglingAutomaticForwardsNewValueToHook() {
    var received: [Bool] = []
    let model = AppUpdateModel(automaticallyChecksForUpdates: true)
    model.onSetAutomatic = { received.append($0) }

    model.automaticallyChecksForUpdates = false
    model.automaticallyChecksForUpdates = true

    #expect(received == [false, true])
}

@MainActor
@Test func checkNowInvokesHookEachCall() {
    var calls = 0
    let model = AppUpdateModel(isUpdaterAvailable: true, canCheckForUpdates: true)
    model.onCheckNow = { calls += 1 }

    model.checkNow()
    model.checkNow()

    #expect(calls == 2)
}

@MainActor
@Test func checkNowIsSafeWhenNoHookWired() {
    let model = AppUpdateModel()
    model.checkNow()   // must not crash with onCheckNow == nil
    #expect(model.isUpdaterAvailable == false)
}

@MainActor
@Test func availableModelReportsVersionStrings() {
    let model = AppUpdateModel(
        isUpdaterAvailable: true,
        canCheckForUpdates: true,
        shortVersion: "0.1.2",
        buildVersion: "123"
    )
    #expect(model.isUpdaterAvailable)
    #expect(model.canCheckForUpdates)
    #expect(model.shortVersion == "0.1.2")
    #expect(model.buildVersion == "123")
}
