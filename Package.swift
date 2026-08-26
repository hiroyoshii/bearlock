// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BearLock",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "BearLockCore", targets: ["BearLockCore"])
    ],
    targets: [
        .target(name: "BearLockCore"),
        .testTarget(
            name: "BearLockCoreTests",
            dependencies: ["BearLockCore"]
        )
    ]
)
