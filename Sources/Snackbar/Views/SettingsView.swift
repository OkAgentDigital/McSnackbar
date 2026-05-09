import SwiftUI

struct SettingsView: View {
    @ObservedObject private var snackManager = SnackManager.shared
    @State private var selectedTab = 0
    @State private var spoolEntries: [SpoolEntry] = []
    @State private var filterText = ""
    @State private var selectedSnackFilter: String? = nil
    
    var body: some View {
        TabView(selection: $selectedTab) {
            snacksTab
                .tabItem {
                    Label("Snacks", systemImage: "square.grid.2x2")
                }
                .tag(0)
            
            spoolTab
                .tabItem {
                    Label("Spool", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 400)
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
                $0.snack.localizedCaseInsensitiveContains(filterText) ||
                $0.output.localizedCaseInsensitiveContains(filterText) ||
                $0.status.localizedCaseInsensitiveContains(filterText)
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
    
    let intervalOptions = [5, 10, 30, 60, 300]
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = NSImage(named: snack.iconName) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading) {
                Text(snack.name)
                    .fontWeight(.medium)
                
                Text(snack.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if snack.id != "notes" && snack.id != "calendar" && snack.id != "permissions" {
                Picker("Interval:", selection: Binding(
                    get: { snack.refreshInterval },
                    set: { onIntervalChange($0) }
                )) {
                    ForEach(intervalOptions, id: \.self) { interval in
                        Text("\(interval)s").tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            
            Toggle("", isOn: Binding(
                get: { snack.isEnabled },
                set: { _ in snackManager.toggleSnack(snack.id) }
            ))
            .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }
}
