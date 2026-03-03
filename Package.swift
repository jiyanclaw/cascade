// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cascade",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "Cascade"
        )
    ]
)
