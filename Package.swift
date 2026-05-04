// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snackbar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Snackbar", targets: ["Snackbar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Snackbar",
            dependencies: [],
            path: "Sources/Snackbar",
            exclude: [
                "Core/AppDelegate.swift",
                "Core/FeedManager.swift",
                "Core/HivemindClient.swift",
                "Core/MenuBuilder.swift",
                "Core/PermissionsManager.swift",
                "Core/SnackExecutor.swift",
                "Core/SnackScheduler.swift",
                "Core/UbuntuProxy.swift",
                "Core/UpdateChecker.swift",
                "Core/XcodeBuildService.swift",
                "Managers/",
                "Models/Category.swift",
                "Models/FeedEntry.swift",
                "Models/Schedule.swift",
                "Models/Snack.swift",
                "Models/uDosComponent.swift",
                "Utils/",
                "Views/"
            ]
        )
    ]
)
