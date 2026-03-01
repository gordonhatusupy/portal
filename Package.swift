// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Portal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PortalCore", targets: ["PortalCore"]),
        .executable(name: "Portal", targets: ["Portal"])
    ],
    targets: [
        .target(
            name: "PortalCore"
        ),
        .executableTarget(
            name: "Portal",
            dependencies: ["PortalCore"]
        ),
        .testTarget(
            name: "PortalCoreTests",
            dependencies: ["PortalCore"]
        )
    ]
)
