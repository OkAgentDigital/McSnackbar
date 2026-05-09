// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Snackbar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Snackbar",
            resources: [
                .process("Assets.xcassets")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
