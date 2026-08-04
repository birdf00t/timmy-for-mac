// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Timmy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Timmy", path: "Sources/Timmy")
    ]
)
