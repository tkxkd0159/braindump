// swift-tools-version: 6.0
import PackageDescription
import Foundation

// CommandLineTools doesn't expose the Swift Testing framework via SwiftPM's
// usual search paths, so the test executable wires them in by hand. The app
// target doesn't need these.
let testingFrameworksPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let testingLibsPath = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

// SwiftDataMacros isn't shipped with Command Line Tools; it's bundled with
// Xcode. Load the plugin explicitly so @Model works when only CLT is on PATH.
let swiftDataMacrosPlugin = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftDataMacros.dylib"

let swiftDataMacroFlag: [String] = {
    if FileManager.default.fileExists(atPath: swiftDataMacrosPlugin) {
        return ["-load-plugin-library", swiftDataMacrosPlugin]
    }
    return []
}()

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
            swiftSettings: swiftDataMacroFlag.isEmpty ? nil : [.unsafeFlags(swiftDataMacroFlag)]
        ),
        .executableTarget(
            name: "todoosx",
            dependencies: ["TodoosxKit"],
            path: "Sources/todoosx",
            swiftSettings: swiftDataMacroFlag.isEmpty ? nil : [.unsafeFlags(swiftDataMacroFlag)]
        ),
        .executableTarget(
            name: "todoosx-test",
            dependencies: ["TodoosxKit"],
            path: "Sources/todoosx-test",
            swiftSettings: [
                .unsafeFlags(["-F", testingFrameworksPath] + swiftDataMacroFlag)
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
