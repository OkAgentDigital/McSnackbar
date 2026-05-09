// SnackbarShortcuts.swift
// Snackbar
//
// Created by DevStudio Integration
//

import AppIntents

/// Registers all Snackbar shortcuts with the system
@available(macOS 13.0, *)
public struct SnackbarShortcuts: AppShortcutsProvider {
    @available(macOS 13.0, *)
    public static var appShortcuts: [AppShortcut] {
        return [
            // Note management shortcuts
            AppShortcut(
                intent: CreateNoteIntent(),
                phrases: [
                    "Create a note in ${applicationName}",
                    "Add a note to ${applicationName}",
                    "Make a new note in ${applicationName}",
                    "Create note \\(.title) in ${applicationName}"
                ],
                shortTitle: "Create Note",
                systemImageName: "note.text.badge.plus"
            ),

            // Sync shortcuts
            AppShortcut(
                intent: SyncNotesIntent(),
                phrases: [
                    "Sync ${applicationName} notes",
                    "Sync my notes with iCloud in ${applicationName}",
                    "Update ${applicationName} notes to iCloud"
                ],
                shortTitle: "Sync Notes",
                systemImageName: "icloud.and.arrow.up"
            ),

            // DevStudio integration shortcuts
            AppShortcut(
                intent: TriggerDevStudioSkillIntent(),
                phrases: [
                    "Run \\(.skillName) in DevStudio through ${applicationName}",
                    "Trigger \\(.skillName) skill in ${applicationName}",
                    "Execute \\(.skillName) in ${applicationName}"
                ],
                shortTitle: "Trigger Skill",
                systemImageName: "bolt.fill"
            )
        ]
    }
}