// swift-tools-version: 6.0
import PackageDescription
import Foundation

// Command Line Tools doesn't ship the macro plugins SwiftData, SwiftUI, and
// Foundation's #Predicate rely on. When Xcode is installed, point the Swift
// compiler at Xcode's plugin directory so those macros expand.
let xcodePluginsPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
let extraPluginFlags: [String] = FileManager.default.fileExists(atPath: xcodePluginsPath)
    ? ["-plugin-path", xcodePluginsPath]
    : []

// Swift Testing framework lives in Command Line Tools and needs explicit
// search/rpath wiring so the test executable can find it at build and run.
let testingFrameworksPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let testingLibsPath = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

let package = Package(
    name: "todoosx",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TodoosxKit", targets: ["TodoosxKit"]),
        .executable(name: "todoosx", targets: ["todoosx"]),
        .executable(name: "todoosx-test", targets: ["todoosx-test"]),
    ],
    targets: [
        .target(
            name: "TodoosxKit",
            path: "Sources/TodoosxKit",
            swiftSettings: extraPluginFlags.isEmpty ? nil : [.unsafeFlags(extraPluginFlags)]
        ),
        .executableTarget(
            name: "todoosx",
            dependencies: ["TodoosxKit"],
            path: "Sources/todoosx",
            swiftSettings: extraPluginFlags.isEmpty ? nil : [.unsafeFlags(extraPluginFlags)]
        ),
        .executableTarget(
            name: "todoosx-test",
            dependencies: ["TodoosxKit"],
            path: "Sources/todoosx-test",
            swiftSettings: [
                .unsafeFlags(["-F", testingFrameworksPath] + extraPluginFlags)
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", testingFrameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", testingFrameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", testingLibsPath,
                ])
            ]
        ),
    ]
)
