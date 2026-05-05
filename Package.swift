// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snackbar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Snackbar", targets: ["Snackbar"]),
        .library(name: "SnackbarCore", targets: ["SnackbarCore"])
    ],
    dependencies: [],
    targets: [
        // ─── SnackbarCore Library ────────────────────────────────────────────
        // DevStudio integration: iCloud sync, note management, MCP client, skill triggering
        .target(
            name: "SnackbarCore",
            dependencies: [],
            path: "Sources/Core",
            exclude: []
        ),

        // ─── Snackbar Executable ─────────────────────────────────────────────
        // The native macOS runtime for uDos — menu bar app with MCP server, spool, scheduler
        .executableTarget(
            name: "Snackbar",
            dependencies: ["SnackbarCore"],
            path: "Sources/Snackbar",
            exclude: [],
            resources: [
                .process("Resources")
            ]
        ),

        // ─── macOS Shortcuts & Automations ───────────────────────────────────
        .target(
            name: "SnackbarAutomations",
            dependencies: ["SnackbarCore"],
            path: "Sources/macOS",
            exclude: []
        ),

        // ─── Tests ───────────────────────────────────────────────────────────
        .testTarget(
            name: "SnackbarTests",
            dependencies: ["SnackbarCore"],
            path: "Tests"
        )
    ]
)
