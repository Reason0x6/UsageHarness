// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "UsageHarness",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "UsageHarness", targets: ["UsageHarness"])
    ],
    targets: [
        .executableTarget(
            name: "UsageHarness",
            path: "Sources/UsageHarness"
        ),
        .testTarget(
            name: "UsageHarnessTests",
            dependencies: ["UsageHarness"],
            path: "Tests/UsageHarnessTests"
        )
    ]
)
