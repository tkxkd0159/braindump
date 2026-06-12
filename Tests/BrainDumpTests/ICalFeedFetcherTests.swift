import Foundation
import Testing
@testable import BrainDumpKit

@Test func fetcherRewritesWebcalToHTTPS() {
    let url = URL(string: "webcal://example.com/feed.ics")!
    #expect(URLSessionICalFeedFetcher.normalize(url).scheme == "https")
}

@Test func fetcherLeavesHTTPSUnchanged() {
    let url = URL(string: "https://example.com/feed.ics")!
    #expect(URLSessionICalFeedFetcher.normalize(url) == url)
}
