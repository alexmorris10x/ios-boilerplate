// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PerformanceNervousSystem",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "PerformanceNervousSystem",
            targets: ["PerformanceNervousSystem"]
        ),
    ],
    targets: [
        .target(name: "PerformanceNervousSystem"),
        .testTarget(
            name: "PerformanceNervousSystemTests",
            dependencies: ["PerformanceNervousSystem"]
        ),
    ]
)
