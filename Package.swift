// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StayAwake",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "StayAwake",
            dependencies: ["StayAwakeShared"],
            path: "Sources/StayAwake"
        ),
        .executableTarget(
            name: "StayAwakeHelper",
            dependencies: ["StayAwakeShared"],
            path: "Sources/StayAwakeHelper"
        ),
        .target(
            name: "StayAwakeShared",
            path: "Sources/StayAwakeShared"
        )
    ]
)
