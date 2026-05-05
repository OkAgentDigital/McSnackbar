import SwiftUI
import AppKit

/// 🍔 Snackbar Settings Window — Stacked layout
///
/// Provides toggles for:
/// - Auto-launch on login
/// - Auto-update checking
/// - Snack ON/OFF toggles
/// - Gift Wrapper / DevStudio surface management
/// - Version info
struct SettingsView: View {
    @StateObject private var settings = SnackbarSettings.shared
    @StateObject private var surfaceManager = SurfaceManager.shared
    @State private var isCheckingForUpdates = false
    @State private var updateStatusText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ── Section: Startup ──
                sectionHeader("Startup", icon: "power")

                VStack(spacing: 12) {
                    Toggle(isOn: $settings.autoLaunch) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-launch on login")
                                .font(.body)
                            Text("Snackbar will start automatically when you log in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(.leading, 8)

                Divider()

                // ── Section: Updates ──
                sectionHeader("Updates", icon: "arrow.down.circle")

                VStack(spacing: 12) {
                    Toggle(isOn: $settings.autoUpdate) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for updates automatically")
                                .font(.body)
                            Text("Snackbar will periodically check GitHub for new releases")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if settings.autoUpdate {
                        HStack {
                            Text("Check interval:")
                                .font(.callout)
                            Picker("", selection: $settings.updateInterval) {
                                Text("Every hour").tag(3600 as TimeInterval)
                                Text("Every 6 hours").tag(21600 as TimeInterval)
                                Text("Every 12 hours").tag(43200 as TimeInterval)
                                Text("Every 24 hours").tag(86400 as TimeInterval)
                                Text("Every 7 days").tag(604800 as TimeInterval)
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                    }

                    // Check now button
                    HStack(spacing: 12) {
                        Button(action: checkForUpdates) {
                            if isCheckingForUpdates {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Checking...")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Check for Updates")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isCheckingForUpdates)

                        if let status = updateStatusText {
                            Text(status)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let lastCheck = settings.lastUpdateCheck {
                        HStack(spacing: 4) {
                            Text("Last checked:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(lastCheck, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Never checked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 8)

                Divider()

                // ── Section: Snacks ──
                sectionHeader("Snacks", icon: "square.grid.2x2")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Toggle each snack ON or OFF. Disabled snacks won't appear in the menu.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    let allSnacks = SnackManager.shared.listSnacks()
                    if allSnacks.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No snacks found. Add .snack files to ~/.snacks/")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(allSnacks) { snack in
                            SnackToggleRow(snack: snack)
                        }
                    }
                }
                .padding(.leading, 8)

                Divider()

                // ── Section: Surfaces ──
                sectionHeader("Surfaces", icon: "square.on.square")

                VStack(alignment: .leading, spacing: 12) {
                    // Gift Wrapper Surfaces toggle
                    Toggle(isOn: $surfaceManager.giftWrapperEnabled) {
                        HStack {
                            Text("🎁")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gift Wrapper Surfaces")
                                    .font(.body)
                                Text("Enable uDosGo USXD surface rendering. Adds a Surfaces > submenu.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)

                    if surfaceManager.giftWrapperEnabled {
                        if surfaceManager.uDosGoSurfaces.isEmpty {
                            Text("No uDosGo surfaces found in ~/Code/uDosGo/surfaces/")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.leading, 28)
                        } else {
                            Text("\(surfaceManager.uDosGoSurfaces.count) surfaces available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                            ForEach(surfaceManager.uDosGoSurfaces) { surface in
                                SurfaceToggleRow(surface: surface, manager: surfaceManager)
                                    .padding(.leading, 28)
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // DevStudio Surfaces toggle
                    Toggle(isOn: $surfaceManager.devStudioSurfacesEnabled) {
                        HStack {
                            Text("💻")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DevStudio Surfaces")
                                    .font(.body)
                                Text("Enable DevStudio surface configs. Adds a Surfaces > submenu.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)

                    if surfaceManager.devStudioSurfacesEnabled {
                        if surfaceManager.devStudioSurfaces.isEmpty {
                            Text("No DevStudio configs found in ~/Code/DevStudio/config/")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.leading, 28)
                        } else {
                            Text("\(surfaceManager.devStudioSurfaces.count) configs available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                            ForEach(surfaceManager.devStudioSurfaces) { surface in
                                SurfaceToggleRow(surface: surface, manager: surfaceManager)
                                    .padding(.leading, 28)
                            }
                        }
                    }
                }
                .padding(.leading, 8)

                Divider()

                // ── Section: About ──
                sectionHeader("About", icon: "info.circle")

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Snackbar")
                                .font(.title2)
                                .fontWeight(.bold)

                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                Text("Version \(version)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                Text("Build \(build)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Text("macOS execution spine of uDos.")
                        .font(.body)
                        .multilineTextAlignment(.center)

                    Text("One icon. One spool. Infinite snacks. One narrator.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()

                    Text("© OkAgentDigital")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.leading, 8)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .frame(width: 520, height: 520)
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundColor(.accentColor)
    }

    // MARK: - Actions

    private func checkForUpdates() {
        isCheckingForUpdates = true
        updateStatusText = nil

        UpdateChecker.shared.checkForUpdates(silent: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
            isCheckingForUpdates = false
            if let lastCheck = settings.lastUpdateCheck,
               Date().timeIntervalSince(lastCheck) < 5 {
                updateStatusText = "✅ You're up to date!"
            } else {
                updateStatusText = "Could not check for updates. Check your internet connection."
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                updateStatusText = nil
            }
        }
    }
}

// MARK: - Snack Toggle Row

struct SnackToggleRow: View {
    let snack: SnackV2
    @State private var isEnabled: Bool = true

    private let enabledKey: String

    init(snack: SnackV2) {
        self.snack = snack
        self.enabledKey = "snack_enabled_\(snack.id)"
        _isEnabled = State(initialValue: UserDefaults.standard.object(forKey: "snack_enabled_\(snack.id)") as? Bool ?? true)
    }

    var body: some View {
        HStack {
            Text(snack.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(snack.name)
                    .font(.body)
                Text(snack.runtime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: enabledKey)
                }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Surface Toggle Row

struct SurfaceToggleRow: View {
    let surface: Surface
    @ObservedObject var manager: SurfaceManager
    @State private var isEnabled: Bool

    init(surface: Surface, manager: SurfaceManager) {
        self.surface = surface
        self.manager = manager
        _isEnabled = State(initialValue: surface.isEnabled)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(surface.name)
                    .font(.body)
                Text(surface.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isEnabled) { _, newValue in
                    manager.toggleSurface(surface, enabled: newValue)
                }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
}
