// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TmuxBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TmuxBar",
            path: "Sources/TmuxBar",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "TmuxBarTests",
            dependencies: ["TmuxBar"],
            path: "Tests/TmuxBarTests"
        ),
    ]
)
