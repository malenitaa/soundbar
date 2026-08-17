// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SoundBar",
    platforms: [.macOS("14.4")],
    targets: [
        .executableTarget(
            name: "SoundBar",
            path: "Sources/SoundBar"
        )
    ]
)
