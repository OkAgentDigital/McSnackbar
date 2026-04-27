import Foundation
import AppKit

class SnackExecutor {
    static func run(_ snack: Snack) {
        var success = false
        var output: String?
        
        do {
            switch snack.runtime {
            case "appleScript":
                guard let script = NSAppleScript(source: snack.code) else {
                    throw SnackError.scriptCompilationFailed
                }
                var error: NSDictionary?
                let result = script.executeAndReturnError(&error)
                if let error = error {
                    throw SnackError.appleScriptError(error.description ?? "Unknown error")
                }
                success = true
                output = result.stringValue
                
            case "shell":
                let task = Process()
                let pipe = Pipe()
                task.launchPath = "/bin/bash"
                task.arguments = ["-c", snack.code]
                task.standardOutput = pipe
                task.standardError = pipe
                try task.run()
                task.waitUntilExit()
                
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if task.terminationStatus != 0 {
                    throw SnackError.shellError("Exit code: \(task.terminationStatus)")
                }
                success = true
                
            default:
                throw SnackError.unknownRuntime(snack.runtime)
            }
        } catch {
            output = error.localizedDescription
        }
        
        // Log to feed
        let feedEntry = FeedEntry(
            snackId: snack.id,
            snackName: snack.name,
            success: success,
            output: output,
            metadata: [
                "runtime": snack.runtime,
                "category": snack.categoryId
            ]
        )
        
        // Get feed manager from AppDelegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.feedManager?.logExecution(feedEntry)
        }
    }
}

enum SnackError: Error {
    case scriptCompilationFailed
    case appleScriptError(String)
    case shellError(String)
    case unknownRuntime(String)
    
    var localizedDescription: String {
        switch self {
        case .scriptCompilationFailed: return "Failed to compile script"
        case .appleScriptError(let msg): return "AppleScript error: \(msg)"
        case .shellError(let msg): return "Shell error: \(msg)"
        case .unknownRuntime(let runtime): return "Unknown runtime: \(runtime)"
        }
    }
}