// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "todoosx",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TodoosxKit", targets: ["TodoosxKit"]),
        .executable(name: "todoosx", targets: ["todoosx"]),
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
        .testTarget(
            name: "todoosxTests",
            dependencies: ["TodoosxKit"],
            path: "Tests/todoosxTests"
        ),
    ]
)
