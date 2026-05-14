import SwiftUI

struct SettingsView: View {
    @ObservedObject private var snackManager = SnackManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared
    @State private var selectedTab = "snacks"
    @State private var spoolEntries: [SpoolEntry] = []
    @State private var filterText = ""
    @State private var selectedSnackFilter: String? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            snacksTab
                .tabItem {
                    Label("Snacks", systemImage: "square.grid.2x2")
                }
                .tag("snacks")

            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag("general")

            spoolTab
                .tabItem {
                    Label("Spool", systemImage: "list.bullet.rectangle")
                }
                .tag("spool")
        }
        .padding()
        .frame(minWidth: 520, minHeight: 460)
        .onAppear {
            loadSpool()
        }
    }

    // MARK: - Snacks Tab

    private var snacksTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Snacks")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enable or disable snacks and set refresh intervals.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            List {
                ForEach(snackManager.snacks) { snack in
                    SnackSettingsRow(snack: snack) { newInterval in
                        snackManager.updateRefreshInterval(for: snack.id, interval: newInterval)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            // ── Section: Startup ──
            Section {
                Toggle(
                    isOn: Binding(
                        get: { snackManager.launchAtStartup },
                        set: { _ in snackManager.toggleLaunchAtStartup() }
                    )
                ) {
                    HStack {
                        Image(systemName: "power")
                            .frame(width: 20)
                        Text("Launch at Startup")
                    }
                }
            } header: {
                Label("Startup", systemImage: "power")
                    .font(.headline)
            }

            Divider()
                .padding(.vertical, 4)

            // ── Section: Updates ──
            Section {
                Toggle(
                    isOn: Binding(
                        get: { updateChecker.updateInterval > 0 },
                        set: { enabled in
                            updateChecker.setUpdateInterval(enabled ? 86400 : 0)
                        }
                    )
                ) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .frame(width: 20)
                        Text("Check for Updates")
                    }
                }

                if updateChecker.updateInterval > 0 {
                    Picker(
                        "Frequency:",
                        selection: Binding(
                            get: { updateChecker.updateInterval },
                            set: { updateChecker.setUpdateInterval($0) }
                        )
                    ) {
                        ForEach(updateChecker.availableIntervals, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 28)

                    HStack {
                        Button("Check Now") {
                            updateChecker.checkForUpdates(silent: false)
                        }
                        .disabled(updateChecker.isChecking)

                        if updateChecker.isChecking {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }

                        Spacer()

                        if let lastCheck = updateChecker.lastCheckDate {
                            Text(
                                "Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 28)

                    if let available = updateChecker.updateAvailable {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Version \(available.version) available!")
                                .fontWeight(.medium)
                            Button("Download") {
                                if let url = URL(string: available.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.leading, 28)
                        .padding(.top, 4)
                    }
                }
            } header: {
                Label("Updates", systemImage: "arrow.down.circle")
                    .font(.headline)
            }

            Spacer()

            // ── Version Info ──
            HStack {
                Spacer()
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                    as? String
                {
                    Text("Snackbar v\(version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Spool Tab

    private var spoolTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spool Viewer")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Refresh") {
                    loadSpool()
                }

                Button("Clear") {
                    SpoolWriter.shared.clear()
                    loadSpool()
                }

                Button("Export...") {
                    exportSpool()
                }
            }

            HStack {
                TextField("Search...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Picker("Filter:", selection: $selectedSnackFilter) {
                    Text("All").tag(nil as String?)
                    ForEach(snackManager.snacks) { snack in
                        Text(snack.name).tag(snack.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                Spacer()
            }

            Table(filteredEntries) {
                TableColumn("Timestamp", value: \.timestamp)
                    .width(min: 180)
                TableColumn("Snack", value: \.snack)
                    .width(min: 80)
                TableColumn("Status", value: \.status)
                    .width(min: 60)
                TableColumn("Output", value: \.output)
                TableColumn("Duration (ms)") { entry in
                    Text("\(entry.durationMs)")
                }
                .width(min: 60)
            }
        }
    }

    private var filteredEntries: [SpoolEntry] {
        var entries = spoolEntries

        if let snackFilter = selectedSnackFilter {
            entries = entries.filter { $0.snack == snackFilter }
        }

        if !filterText.isEmpty {
            entries = entries.filter {
                $0.snack.localizedCaseInsensitiveContains(filterText)
                    || $0.output.localizedCaseInsensitiveContains(filterText)
                    || $0.status.localizedCaseInsensitiveContains(filterText)
            }
        }

        return entries
    }

    private func loadSpool() {
        spoolEntries = SpoolWriter.shared.readAll().reversed()
    }

    private func exportSpool() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "snackbar-spool.jsonl"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                SpoolWriter.shared.export(to: url)
            }
        }
    }
}

struct SnackSettingsRow: View {
    @ObservedObject private var snackManager = SnackManager.shared
    let snack: Snack
    let onIntervalChange: (Int) -> Void

    @State private var sliderValue: Double = 60

    var body: some View {
        HStack(spacing: 12) {
            if let icon = NSImage(named: snack.iconName) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "circle.fill")
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(snack.name)
                    .fontWeight(.medium)

                Text(snack.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if snack.id != "notes" && snack.id != "calendar" && snack.id != "permissions" {
                VStack(alignment: .trailing, spacing: 2) {
                    Slider(
                        value: $sliderValue,
                        in: 5...300,
                        step: 5
                    ) {
                        Text("Refresh interval")
                    } onEditingChanged: { editing in
                        if !editing {
                            let newInterval = Int(sliderValue)
                            onIntervalChange(newInterval)
                        }
                    }
                    .frame(width: 120)

                    Text(formatInterval(Int(sliderValue)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .onAppear {
                    sliderValue = Double(snack.refreshInterval)
                }
                .onChange(of: snack.refreshInterval) { _, newValue in
                    sliderValue = Double(newValue)
                }
            }

            Toggle(
                "",
                isOn: Binding(
                    get: { snack.isEnabled },
                    set: { _ in snackManager.toggleSnack(snack.id) }
                )
            )
            .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }

    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m \(seconds % 60)s"
        } else {
            return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
        }
    }
}
