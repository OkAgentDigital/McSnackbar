import Foundation

/// Result of a snack execution
struct SnackExecutionResult {
    let exitCode: Int32
    let output: String
    let stdout: String
    let stderr: String
    let durationMs: Int
    let spoolEntry: SpoolEntry?
}

/// Executes snacks (AppleScript, shell, etc.) and writes results to the spool.
class SnackExecutor {
    
    /// Execute a snack and write to spool.
    func execute(snack: SnackV2, inputs: [String: String]? = nil) -> SnackExecutionResult {
        let startTime = Date()
        var stdout = ""
        var stderr = ""
        var exitCode: Int32 = -1
        
        switch snack.runtime {
        case "apple-script-osx":
            (exitCode, stdout, stderr) = executeAppleScript(snack.code)
        case "shell":
            (exitCode, stdout, stderr) = executeShell(snack.code)
        default:
            stderr = "Unknown runtime: \(snack.runtime)"
            exitCode = 127
        }
        
        let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)
        let output = stdout.isEmpty ? stderr : stdout
        
        // Build spool entry
        let entry = SpoolEntry(
            reply_id: SpoolEntry.generateReplyId(snackId: snack.id),
            thread_id: SpoolEntry.generateThreadId(snackName: snack.name),
            timestamp: SpoolEntry.currentTimestamp(),
            source: "snack_execution",
            user_id: NSUserName(),
            compartment: "snacks/\(snack.name.lowercased())",
            prompt: "ucode snack run \(snack.id)",
            output: output.trimmingCharacters(in: .newlines),
            tags: ["snack", snack.name.lowercased().replacingOccurrences(of: " ", with: "_")] + (exitCode == 0 ? ["success"] : ["error"]),
            metadata: SpoolMetadata(
                snack_id: snack.id,
                snack_name: snack.name,
                runtime: snack.runtime,
                duration_ms: durationMs,
                exit_code: exitCode,
                stdout: stdout,
                stderr: stderr.isEmpty ? nil : stderr,
                inputs: inputs,
                outputs: nil,
                nugget_pointer: nil
            )
        )
        
        // Write to spool
        SpoolManager.shared.append(entry)
        
        // Evaluate rules
        let actions = RulesManager.shared.evaluateTriggers(snackOutput: (snack.id, exitCode))
        for action in actions {
            handleRuleAction(action)
        }
        
        return SnackExecutionResult(
            exitCode: exitCode,
            output: output.trimmingCharacters(in: .newlines),
            stdout: stdout,
            stderr: stderr,
            durationMs: durationMs,
            spoolEntry: entry
        )
    }
    
    // MARK: - Runtime Execution
    
    private func executeAppleScript(_ code: String) -> (Int32, String, String) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", code]
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            return (
                task.terminationStatus,
                String(data: outputData, encoding: .utf8) ?? "",
                String(data: errorData, encoding: .utf8) ?? ""
            )
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }
    
    private func executeShell(_ code: String) -> (Int32, String, String) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", code]
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            return (
                task.terminationStatus,
                String(data: outputData, encoding: .utf8) ?? "",
                String(data: errorData, encoding: .utf8) ?? ""
            )
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }
    
    // MARK: - Rule Action Handling
    
    private func handleRuleAction(_ action: RuleAction) {
        switch action.type {
        case .run_snack:
            if let snackId = action.snack_id, let snack = SnackManager.shared.getSnack(byId: snackId) {
                let params = action.params?.mapValues { "\($0.value)" }
                _ = execute(snack: snack, inputs: params)
            }
        case .notify:
            let title = action.notification_title ?? "Snackbar Rule"
            let body = action.notification_body ?? "Rule triggered"
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = body
            NSUserNotificationCenter.default.deliver(notification)
        case .run_shortcut:
            if let shortcutName = action.shortcut_name {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                task.arguments = ["run", shortcutName]
                try? task.run()
            }
        case .script:
            if let script = action.script {
                _ = executeShell(script)
            }
        }
    }
}

