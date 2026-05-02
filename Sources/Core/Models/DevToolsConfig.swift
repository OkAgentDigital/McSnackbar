// DevToolsConfig.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation

/// Configuration for development tools and agent instructions
public struct DevToolsConfig: Codable {
    public var xcode: XcodeConfig
    public var swift: SwiftConfig
    public var debugging: DebuggingConfig
    public var compilation: CompilationConfig
    public var agents: [AgentConfig]
    public var environment: EnvironmentConfig
    public var paths: PathConfig
    public var lastUpdated: Date

    public init(
        xcode: XcodeConfig = XcodeConfig(),
        swift: SwiftConfig = SwiftConfig(),
        debugging: DebuggingConfig = DebuggingConfig(),
        compilation: CompilationConfig = CompilationConfig(),
        agents: [AgentConfig] = [],
        environment: EnvironmentConfig = EnvironmentConfig(),
        paths: PathConfig = PathConfig(),
        lastUpdated: Date = Date()
    ) {
        self.xcode = xcode
        self.swift = swift
        self.debugging = debugging
        self.compilation = compilation
        self.agents = agents
        self.environment = environment
        self.paths = paths
        self.lastUpdated = lastUpdated
    }

    public struct XcodeConfig: Codable {
        public var path: String
        public var version: String
        public var commandLineToolsPath: String
        public var preferredSimulator: String
        
        public init(
            path: String = "/Applications/Xcode.app",
            version: String = "14.0",
            commandLineToolsPath: String = "/Library/Developer/CommandLineTools",
            preferredSimulator: String = "iPhone 14"
        ) {
            self.path = path
            self.version = version
            self.commandLineToolsPath = commandLineToolsPath
            self.preferredSimulator = preferredSimulator
        }
    }

    public struct SwiftConfig: Codable {
        public var version: String
        public var formatOptions: [String]
        public var lintOptions: [String]
        
        public init(
            version: String = "5.7",
            formatOptions: [String] = ["--indent", "4", "--linewidth", "120"],
            lintOptions: [String] = ["--strict"]
        ) {
            self.version = version
            self.formatOptions = formatOptions
            self.lintOptions = lintOptions
        }
    }

    public struct DebuggingConfig: Codable {
        public var consoleCommands: [ConsoleCommand]
        public var errorPatterns: [ErrorPattern]
        public var logLevel: String
        public var enableAdvancedLogging: Bool
        
        public init(
            consoleCommands: [ConsoleCommand] = ConsoleCommand.defaultCommands,
            errorPatterns: [ErrorPattern] = ErrorPattern.defaultPatterns,
            logLevel: String = "info",
            enableAdvancedLogging: Bool = false
        ) {
            self.consoleCommands = consoleCommands
            self.errorPatterns = errorPatterns
            self.logLevel = logLevel
            self.enableAdvancedLogging = enableAdvancedLogging
        }
    }

    public struct CompilationConfig: Codable {
        public var commonFlags: [String]
        public var warningFlags: [String]
        public var optimizationFlags: [String]
        public var frameworkSearchPaths: [String]
        public var enableCodeCoverage: Bool
        
        public init(
            commonFlags: [String] = ["-enable-testing"],
            warningFlags: [String] = ["-warn-all", "-warn-error"],
            optimizationFlags: [String] = ["-O"],
            frameworkSearchPaths: [String] = [],
            enableCodeCoverage: Bool = false
        ) {
            self.commonFlags = commonFlags
            self.warningFlags = warningFlags
            self.optimizationFlags = optimizationFlags
            self.frameworkSearchPaths = frameworkSearchPaths
            self.enableCodeCoverage = enableCodeCoverage
        }
    }

    public struct AgentConfig: Codable {
        public var name: String
        public var description: String
        public var executablePath: String
        public var arguments: [String]
        public var environmentVariables: [String: String]
        public var isEnabled: Bool
        
        public init(
            name: String,
            description: String,
            executablePath: String,
            arguments: [String] = [],
            environmentVariables: [String: String] = [:],
            isEnabled: Bool = true
        ) {
            self.name = name
            self.description = description
            self.executablePath = executablePath
            self.arguments = arguments
            self.environmentVariables = environmentVariables
            self.isEnabled = isEnabled
        }
    }

    public struct EnvironmentConfig: Codable {
        public var variables: [String: String]
        public var pathExtensions: [String]
        public var conditionalVariables: [ConditionalVariable]
        
        public init(
            variables: [String: String] = [:],
            pathExtensions: [String] = [],
            conditionalVariables: [ConditionalVariable] = []
        ) {
            self.variables = variables
            self.pathExtensions = pathExtensions
            self.conditionalVariables = conditionalVariables
        }
    }

    public struct PathConfig: Codable {
        public var projectRoot: String
        public var buildDirectory: String
        public var derivedDataPath: String
        public var cacheDirectory: String
        
        public init(
            projectRoot: String = "~/Code/Apps/Snackbar",
            buildDirectory: String = ".build",
            derivedDataPath: String = "~/Library/Developer/Xcode/DerivedData",
            cacheDirectory: String = "~/Library/Caches/com.udos.Snackbar"
        ) {
            self.projectRoot = projectRoot
            self.buildDirectory = buildDirectory
            self.derivedDataPath = derivedDataPath
            self.cacheDirectory = cacheDirectory
        }
    }

    public struct ConsoleCommand: Codable {
        public var name: String
        public var command: String
        public var description: String
        public var shortcut: String
        
        public static var defaultCommands: [ConsoleCommand] = [
            ConsoleCommand(
                name: "Clean Build",
                command: "xcodebuild clean",
                description: "Clean all build products",
                shortcut: "⌘⇧K"
            ),
            ConsoleCommand(
                name: "Build Project",
                command: "xcodebuild -scheme Snackbar",
                description: "Build the project",
                shortcut: "⌘B"
            ),
            ConsoleCommand(
                name: "Run Tests",
                command: "xcodebuild test -scheme SnackbarTests",
                description: "Run all tests",
                shortcut: "⌘U"
            ),
            ConsoleCommand(
                name: "Swift Format",
                command: "swiftformat .",
                description: "Format all Swift files",
                shortcut: "⌘⇧F"
            ),
            ConsoleCommand(
                name: "Swift Lint",
                command: "swiftlint",
                description: "Lint all Swift files",
                shortcut: "⌘⇧L"
            )
        ]
    }

    public struct ErrorPattern: Codable {
        public var pattern: String
        public var type: String
        public var description: String
        public var suggestedFix: String
        
        public static var defaultPatterns: [ErrorPattern] = [
            ErrorPattern(
                pattern: "undefined.*symbol",
                type: "linker",
                description: "Undefined symbol error",
                suggestedFix: "Check framework linkages and import statements"
            ),
            ErrorPattern(
                pattern: "use of unresolved identifier",
                type: "compiler",
                description: "Unresolved identifier",
                suggestedFix: "Check variable/function names and imports"
            ),
            ErrorPattern(
                pattern: "Cannot convert value of type",
                type: "compiler",
                description: "Type conversion error",
                suggestedFix: "Check type annotations and conversions"
            ),
            ErrorPattern(
                pattern: "Command.*failed with.*exit code",
                type: "build",
                description: "Build command failed",
                suggestedFix: "Check the specific command output for details"
            ),
            ErrorPattern(
                pattern: "Module.*not found",
                type: "module",
                description: "Module not found",
                suggestedFix: "Check framework search paths and module availability"
            )
        ]
    }

    public struct ConditionalVariable: Codable {
        public var name: String
        public var condition: String
        public var value: String
        
        public init(name: String, condition: String, value: String) {
            self.name = name
            self.condition = condition
            self.value = value
        }
    }
}

// MARK: - Extensions for Common Operations
extension DevToolsConfig {
    public static func defaultConfig() -> DevToolsConfig {
        return DevToolsConfig()
    }

    public mutating func updatePaths(forProject projectPath: String) {
        paths.projectRoot = projectPath
        paths.buildDirectory = "" + projectPath + "/.build"
    }

    public func getConsoleCommand(named name: String) -> ConsoleCommand? {
        return debugging.consoleCommands.first { $0.name == name }
    }

    public func getErrorPattern(forError error: String) -> ErrorPattern? {
        return debugging.errorPatterns.first { error.contains($0.pattern) }
    }
}