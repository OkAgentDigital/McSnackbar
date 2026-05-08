// SnackbarApp.swift
// Snackbar
//
// Created by DevStudio Integration
//
// NOTE: App entry point is Sources/Snackbar/main.swift (SnackbarAppDelegate).
// This file provides the Settings scene for SwiftUI and is NOT @main.

import SwiftUI
import Snackbar

struct SnackbarApp: App {
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
