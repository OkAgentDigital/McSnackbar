// XcodeBuildService.swift
// Snackbar
//
// Xcode External Agent integration — allows Snackbar to:
// 1. Trigger builds of HivemindRust and other projects
// 2. Receive build notifications from Xcode
// 3. Act as an Xcode External Agent for build automation
//
// Based on Apple's External Agent documentation:
// https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode
//
// Created by DevStudio Integration

import Foundation
import AppKit

/// Service for integrating with Xcode as an External Agent.
/// Provides build triggering, status monitoring, and notification handling.
public class XcodeBuildService: ObservableObject {
    public static let shared = XcodeBuildService()

    @Published public private(set) var isBuilding: Bool = false
    @Published public private(set) var lastBuildResult: BuildResult?
    @Published public private(set) var buildLog: String = ""
    @Published public private(set) var xcServiceAvailable: Bool = false

    /// Known projects that can be built.
    public let knownProjects: [XcodeProject] = [
        XcodeProject(
            name: "HivemindRust",
            path: "~/Code/OkAgentDigital/HivemindRust",
            scheme: "hivemind-rust",
            type: .rust
        ),
        XcodeProject(
            name: "Snackbar",
            path: "~/Code/Apps/Snackbar",
            scheme: "Snackbar",
            type: .xcode
        ),
        XcodeProject(
            name: "Re3Engine",
            path: "~/Code/OkAgentDigital/Re3Engine",
            scheme: "re3engine",
            type: .rust
        )
    ]

    private let notificationCenter: NotificationCenter
    private let fileManager: FileManager

    public init() {
        self.notificationCenter = .default
        self.fileManager = .default
        checkXcodeAvailability()
    }

    // MARK: - Xcode External Agent Integration

    /// Check if Xcode command line tools are available.
    private func checkXcodeAvailability() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        task.arguments = ["-p"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            xcServiceAvailable = task.terminationStatus == 0
        } catch {
            xcServiceAvailable = false
        }
    }

    /// Build a project using xcodebuild (for Xcode projects) or cargo (for Rust projects).
    /// - Parameter project: The project to build.
    /// - Returns: BuildResult with success/failure and output.
    public func buildProject(_ project: XcodeProject) async -> BuildResult {
        await MainActor.run { [weak self] in
            self?.isBuilding = true
            self?.lastBuildResult = nil
        }

        let result: BuildResult

        switch project.type {
        case .xcode:
            result = buildWithXcodebuild(project)
        case .rust:
            result = buildWithCargo(project)
        }

        await MainActor.run { [weak self] in
            self?.isBuilding = false
            self?.lastBuildResult = result
            if let log = result.log {
                self?.buildLog = (self?.buildLog ?? "") + log + "\n"
            }
        }

        // Post notification
        postBuildNotification(result, project: project)

        return result
    }

    /// Build an Xcode project using xcodebuild.
    private func buildWithXcodebuild(_ project: XcodeProject) -> BuildResult {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let projectPath = (project.path as NSString).expandingTildeInPath

        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        task.arguments = [
            "-project", "\(projectPath)/\(project.name).xcodeproj",
            "-scheme", project.scheme,
            "-configuration", "Release",
            "build"
        ]
        task.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        let startTime = Date()

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: outputData, encoding: .utf8) ?? ""
            let stderr = String(data: errorData, encoding: .utf8) ?? ""
            let duration = Date().timeIntervalSince(startTime)

            return BuildResult(
                success: task.terminationStatus == 0,
                projectName: project.name,
                duration: duration,
                log: stdout + stderr,
                error: task.terminationStatus != 0 ? "xcodebuild exited with code \(task.terminationStatus)" : nil
            )
        } catch {
            return BuildResult(
                success: false,
                projectName: project.name,
                duration: Date().timeIntervalSince(startTime),
                log: nil,
                error: error.localizedDescription
            )
        }
    }

    /// Build a Rust project using cargo.
    private func buildWithCargo(_ project: XcodeProject) -> BuildResult {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let projectPath = (project.path as NSString).expandingTildeInPath

        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["cargo", "build", "--release"]
        task.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        let startTime = Date()

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: outputData, encoding: .utf8) ?? ""
            let stderr = String(data: errorData, encoding: .utf8) ?? ""
            let duration = Date().timeIntervalSince(startTime)

            return BuildResult(
                success: task.terminationStatus == 0,
                projectName: project.name,
                duration: duration,
                log: stdout + stderr,
                error: task.terminationStatus != 0 ? "cargo exited with code \(task.terminationStatus)" : nil
            )
        } catch {
            return BuildResult(
                success: false,
                projectName: project.name,
                duration: Date().timeIntervalSince(startTime),
                log: nil,
                error: error.localizedDescription
            )
        }
    }

    /// Build all known projects sequentially.
    public func buildAll() async -> [BuildResult] {
        var results: [BuildResult] = []
        for project in knownProjects {
            let result = await buildProject(project)
            results.append(result)
        }
        return results
    }

    /// Post a macOS notification about the build result.
    private func postBuildNotification(_ result: BuildResult, project: XcodeProject) {
        let notification = NSUserNotification()
        notification.title = result.success ? "✅ Build Succeeded" : "❌ Build Failed"
        notification.informativeText = "\(project.name) — \(result.durationFormatted)"
        notification.soundName = result.success ? nil : NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    /// Clear the build log.
    public func clearBuildLog() {
        buildLog = ""
    }
}

// MARK: - Supporting Types

/// An Xcode or Rust project that can be built.
public struct XcodeProject: Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let scheme: String
    public let type: ProjectType

    public init(name: String, path: String, scheme: String, type: ProjectType) {
        self.id = name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.path = path
        self.scheme = scheme
        self.type = type
    }
}

/// Type of project to build.
public enum ProjectType: String, Codable {
    case xcode
    case rust
}

/// Result of a build operation.
public struct BuildResult {
    public let success: Bool
    public let projectName: String
    public let duration: TimeInterval
    public let log: String?
    public let error: String?

    public var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    public var summary: String {
        let icon = success ? "✅" : "❌"
        return "\(icon) \(projectName) — \(durationFormatted)"
    }
}
