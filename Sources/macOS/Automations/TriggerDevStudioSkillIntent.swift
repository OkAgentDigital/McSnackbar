// TriggerDevStudioSkillIntent.swift
// Snackbar
//
// Created by DevStudio Integration
//

import AppIntents
import SnackbarCore

struct TriggerDevStudioSkillIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger DevStudio Skill"
    static var description = IntentDescription("Triggers a DevStudio skill from Snackbar.")
    
    @Parameter(title: "Skill Name")
    var skillName: String
    
    @Parameter(title: "Arguments", default: [])
    var arguments: [String]
    
    static var parameterSummary: some ParameterSummary {
        Summary("Trigger **\\(\.skillName)** skill")
    }
    
    func perform() async throws -> some IntentResult {
        let skillTrigger = DevStudioSkillTrigger.shared
        let command = arguments.isEmpty ? skillName : "" + skillName + " " + arguments.joined(separator: " ")
        
        return await .result(value: try await withCheckedThrowingContinuation { continuation in
            skillTrigger.runSkill(command: command) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        })
    }
}