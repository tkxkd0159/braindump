// swift-tools-version: 6.0
import PackageDescription

// CommandLineTools doesn't expose the Swift Testing framework via SwiftPM's
// usual search paths, so the test executable wires them in by hand. The app
// target doesn't need these.
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
            path: "Sources/TodoosxKit"
        ),
        .executableTarget(
            name: "todoosx",
            dependencies: ["TodoosxKit"],
            path: "Sources/todoosx"
        ),
        .executableTarget(
            name: "todoosx-test",
            dependencies: ["TodoosxKit"],
            path: "Sources/todoosx-test",
            swiftSettings: [
                .unsafeFlags(["-F", testingFrameworksPath])
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
