// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrainDumpKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BrainDumpKit", targets: ["BrainDumpKit"]),
    ],
    targets: [
        .target(
            name: "BrainDumpKit",
            path: "Sources/BrainDumpKit",
            resources: [
                .process("Resources/Fonts"),
            ]
        ),
        .testTarget(
            name: "BrainDumpTests",
            dependencies: ["BrainDumpKit"],
            path: "Tests/BrainDumpTests"
        ),
    ]
)
