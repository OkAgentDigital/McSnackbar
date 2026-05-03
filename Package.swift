// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Snackbar",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Snackbar", targets: ["Snackbar"]),
    ],
    targets: [
        .executableTarget(
            name: "Snackbar",
            path: ".",
            exclude: [
                "build",
                ".build",
                "dev",
                "Dev",
                "release",
                "Scripts",
                "Tests",
                "DevStudio",
                "LAUNCH_INSTRUCTIONS.md",
                "ROADMAP.md",
                "CONSOLIDATED_SUMMARY.md",
                "SNACKBAR_SUMMARY.md",
                "README.md",
                "config.yaml",
                "project.yml",
                "Snackbar.code-workspace",
                "Snackbar.command",
                "Dev-Launch.command",
                "Resources/Snackbar.entitlements",
                "Resources/Snackbar.sdef",
                "Sources/Core",
                "Sources/macOS",
                "Sources/EnhancedSnackbar",
                "Sources/CompleteSnackbar",
                "Sources/SimpleSnackbar",
                "Sources/MainSpine"
            ],
            sources: ["Sources/Snackbar"],
            resources: [
                .process("Resources/categories.json"),
                .process("Resources/snacks.json"),
                .process("Resources/ABOUT.md")
            ]
        ),
    ]
)
