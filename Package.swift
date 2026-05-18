// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sweep",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Sweep", targets: ["Sweep"]),
    ],
    targets: [
        .target(
            name: "Sweep",
            path: "Sources/Sweep"
        ),
        .executableTarget(
            name: "SweepMain",
            dependencies: ["Sweep"],
            path: "Sources/SweepMain"
        ),
        .testTarget(
            name: "SweepTests",
            dependencies: ["Sweep"],
            path: "Tests/SweepTests"
        )
    ]
)
