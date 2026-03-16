// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AranetBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "AranetBar", path: "Sources/AranetBar"),
    ]
)
