// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CursorSubtitles",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CursorSubtitles",
            path: "Sources/CursorSubtitles"
        )
    ]
)
