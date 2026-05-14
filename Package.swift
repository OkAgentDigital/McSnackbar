// swift-tools-version: 6.3
// Code signing for macOS apps is managed via Xcode or external tools, not via SwiftPM.
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
            ], // Bundling asset catalogs
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
