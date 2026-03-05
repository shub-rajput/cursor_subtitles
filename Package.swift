// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pubbles",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pubbles",
            path: "Sources/Pubbles"
        )
    ]
)
