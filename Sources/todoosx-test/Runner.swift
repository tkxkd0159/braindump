import Foundation
import Darwin
import Testing

@main
struct TestRunner {
    static func main() async {
        let code: CInt = await Testing.__swiftPMEntryPoint()
        Darwin._exit(code)
    }
}
