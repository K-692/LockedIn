// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LockedIn",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "LockedIn",
            targets: ["LockedIn"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LockedIn",
            path: "LockedIn",
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
