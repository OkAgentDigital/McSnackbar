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
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("Assets.xcassets")
            ],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
