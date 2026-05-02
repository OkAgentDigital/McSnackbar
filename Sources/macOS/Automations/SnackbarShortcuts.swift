// SnackbarShortcuts.swift
// Snackbar
//
// Created by DevStudio Integration
//

import AppIntents

/// Registers all Snackbar shortcuts with the system
public struct SnackbarShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        return [
            // Note management shortcuts
            AppShortcut(
                intent: CreateNoteIntent(),
                phrases: [
                    "Create a note in Snackbar",
                    "Add a note to Snackbar",
                    "Make a new note in Snackbar",
                    "Create note \\(.title) in Snackbar"
                ],
                shortTitle: "Create Note",
                systemImageName: "note.text.badge.plus"
            ),
            
            // Sync shortcuts
            AppShortcut(
                intent: SyncNotesIntent(),
                phrases: [
                    "Sync Snackbar notes",
                    "Sync my notes with iCloud in Snackbar",
                    "Update Snackbar notes to iCloud"
                ],
                shortTitle: "Sync Notes",
                systemImageName: "icloud.and.arrow.up"
            ),
            
            // DevStudio integration shortcuts
            AppShortcut(
                intent: TriggerDevStudioSkillIntent(),
                phrases: [
                    "Run \\(.skillName) in DevStudio",
                    "Trigger \\(.skillName) skill",
                    "Execute \\(.skillName) in Snackbar"
                ],
                shortTitle: "Trigger Skill",
                systemImageName: "bolt.fill"
            )
        ]
    }
}