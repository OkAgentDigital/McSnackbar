// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Snackbar",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Snackbar", targets: ["Snackbar"])
    ],
    targets: [
        .executableTarget(
            name: "Snackbar",
            dependencies: [],
            resources: [
                .copy("Resources/snacks.json"),
                .copy("Resources/categories.json"),
                .copy("Resources/ABOUT.md")
            ]
        )
    ]
)