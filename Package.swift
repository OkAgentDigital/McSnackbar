// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "McSnackbar",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Snackbar", targets: ["Snackbar"]),
        .executable(name: "SimpleSnackbar", targets: ["SimpleSnackbar"]),
    ],
    targets: [
        .executableTarget(
            name: "SimpleSnackbar",
            path: "Sources/SimpleSnackbar"
        ),
        .executableTarget(
            name: "Snackbar",
            dependencies: [],
            path: ".",
            exclude: [
                "Sources/SimpleSnackbar",
                "Sources/MainSpine",
                "Sources/CompleteSnackbar",
                "Sources/EnhancedSnackbar",
                "Sources/Core",
                "Sources/Shared",
                "Sources/macOS",
                "Snackbar.xcodeproj",
                "DevStudio",
                "Scripts",
                "Tests",
                "build",
                ".build",
                "Dev-Launch.command",
                "Snackbar.code-workspace",
                "Resources/Info.plist",
                "Resources/Snackbar.entitlements",
                "Resources/Snackbar.sdef",
                "PROJECT_STRUCTURE.md",
                "CONSOLIDATED_SUMMARY.md",
                "LAUNCH_INSTRUCTIONS.md",
                "ROADMAP.md",
                "README.md",
                "SNACKBAR_SUMMARY.md",
                "project.yml",
                "config.yaml",
                "Snackbar.app",
                "Snackbar.command",
            ],
            sources: ["Sources/Snackbar"],
            resources: [
                .process("Resources/categories.json"),
                .process("Resources/snacks.json"),
                .process("Resources/ABOUT.md"),
            ]
        ),
    ]
)
