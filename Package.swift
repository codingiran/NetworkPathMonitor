// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkPathMonitor",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NetworkPathMonitor",
            targets: ["NetworkPathMonitor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/codingiran/NetworkKit.git", .upToNextMajor(from: "0.2.8")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NetworkPathMonitor",
            dependencies: [
                "NetworkKit",
            ],
            linkerSettings: [
                .linkedFramework("Network"),
            ]
        ),
        .testTarget(
            name: "NetworkPathMonitorTests",
            dependencies: ["NetworkPathMonitor"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
