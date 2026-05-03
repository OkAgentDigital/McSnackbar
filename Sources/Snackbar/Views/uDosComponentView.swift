import SwiftUI
import AppKit
import UserNotifications

struct uDosComponentView: View {
    @StateObject private var manager = uDosProcessManager()
    @StateObject private var hivemindClient = HivemindClient.shared
    @StateObject private var ubuntuProxy = UbuntuProxy.shared
    @State private var selectedComponent: uDosComponent?
    @State private var showingLogs = false
    @State private var showingSettings = false
    @State private var showingPreferences = false
    @State private var selectedLogComponent: String?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("🍫 uDos Component Manager")
                    .font(.headline)
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    ForEach(manager.components, id: \.id) { component in
                        ComponentStatusIndicator(component: component, status: manager.processes[component.id])
                    }
                }
            }
            
            Divider()
            
            // ─── Hivemind Status Panel ──────────────────────────────────────
            HivemindStatusPanel(hivemindClient: hivemindClient)
            
            // ─── Ubuntu Backend Status Panel ────────────────────────────────
            UbuntuStatusPanel(ubuntuProxy: ubuntuProxy)
            
            Divider()
            
            // Components list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(manager.components) { component in
                        ComponentRow(
                            component: component,
                            status: manager.processes[component.id],
                            onStart: {
                                manager.startComponent(component)
                            },
                            onStop: {
                                manager.stopComponent(component)
                            },
                            onRestart: {
                                manager.restartComponent(component)
                            },
                            onViewLogs: {
                                selectedLogComponent = component.id
                                showingLogs = true
                            },
                            onTestConnection: {
                                testConnection(component: component)
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Logs section
            if showingLogs {
                showingLogsView
            }
            
            // Preferences section
            if showingPreferences {
                preferencesView
            }
            
            // Settings section
            if showingSettings {
                settingsView
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500)
        .onAppear {
            // Request notification permissions
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if granted {
                    print("✅ Notification permissions granted")
                } else if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
            }
            
            // Refresh Hivemind status on appear
            Task {
                _ = await hivemindClient.listTools()
                _ = await hivemindClient.getStatus()
                ubuntuProxy.performHealthCheck()
            }
        }
    }

    private var showingLogsView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("📋 Logs for: \(selectedLogComponent ?? "Unknown")")
                Spacer()
                Button("Close") {
                    showingLogs = false
                }
            }
            
            ScrollView {
                Text(manager.getLogs(for: selectedLogComponent ?? "").joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack {
                Button("Clear Logs") {
                    manager.clearLogs()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Export Logs") {
                    exportLogs()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private var preferencesView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("⚙️ Preferences")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    showingPreferences = false
                }
            }
            
            Form {
                Toggle("Launch on login", isOn: $manager.launchOnLogin)
                Toggle("Auto-restart failed components", isOn: $manager.autoRestart)
                Toggle("Show notifications", isOn: $manager.showNotifications)
                
                Section(header: Text("uDos Path")) {
                    TextField("Path to uDos", text: $manager.uDosPath)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section(header: Text("Actions")) {
                    Button("Save Settings") {
                        manager.saveSettings()
                        showingPreferences = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private var settingsView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🔧 Settings")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    showingSettings = false
                }
            }
            
            Form {
                Section(header: Text("Components")) {
                    ForEach(manager.components) { component in
                        HStack {
                            Text(component.displayName)
                            Spacer()
                            Button("Edit") {
                                // Edit component
                            }
                            Button("Remove") {
                                manager.removeComponent(withId: component.id)
                            }
                        }
                    }
                }
                
                Section(header: Text("Add Component")) {
                    Button("Add New Component") {
                        // Add new component
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func testConnection(component: uDosComponent) {
        guard let url = component.healthCheckURL else {
            print("❌ No health check URL for \(component.displayName)")
            return
        }
        
        print("🔍 Testing connection to \(url)...")
        URLSession.shared.dataTask(with: URL(string: url)!) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("✅ Connection successful for \(component.displayName)")
                } else if let error = error {
                    print("❌ Connection failed for \(component.displayName): \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    private func exportLogs() {
        let logContent = manager.getLogs(for: selectedLogComponent ?? "").joined(separator: "\n")
        let savePanel = NSSavePanel()
        savePanel.title = "Export Logs"
        savePanel.nameFieldStringValue = "uDos_Logs_\(Date().formatted()).txt"
        savePanel.allowedContentTypes = [.text]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try logContent.write(to: url, atomically: true, encoding: .utf8)
                print("✅ Logs exported to: \(url.path)")
            } catch {
                print("❌ Failed to export logs: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Hivemind Status Panel

struct HivemindStatusPanel: View {
    @ObservedObject var hivemindClient: HivemindClient
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("🧠 HivemindRust")
                    .font(.subheadline).bold()
                Spacer()
                Text(hivemindClient.isConnected ? "✅ Connected" : "⏹️ Disconnected")
                    .foregroundColor(hivemindClient.isConnected ? .green : .gray)
            }
            
            if hivemindClient.isConnected {
                HStack {
                    Text("Version: \(hivemindClient.serverVersion)")
                        .font(.caption)
                    Spacer()
                    Text("Tools: \(hivemindClient.availableTools.count) available")
                        .font(.caption)
                }
                
                if !hivemindClient.availableTools.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(hivemindClient.availableTools.prefix(5)) { tool in
                                Text(tool.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            if hivemindClient.availableTools.count > 5 {
                                Text("+\(hivemindClient.availableTools.count - 5) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Ubuntu Backend Status Panel

struct UbuntuStatusPanel: View {
    @ObservedObject var ubuntuProxy: UbuntuProxy
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("🌐 Ubuntu Backend")
                    .font(.subheadline).bold()
                Spacer()
                Text(ubuntuProxy.isReachable ? "✅ SSH Connected" : "❌ SSH Disconnected")
                    .foregroundColor(ubuntuProxy.isReachable ? .green : .red)
            }
            
            HStack(spacing: 16) {
                Label(
                    title: { Text("Ollama: \(ubuntuProxy.ollamaStatus.displayText)").font(.caption) },
                    icon: { Image(systemName: "cpu") }
                )
                Label(
                    title: { Text("Hivemind: \(ubuntuProxy.hivemindStatus.displayText)").font(.caption) },
                    icon: { Image(systemName: "network") }
                )
            }
            
            HStack {
                Button("🔄 Refresh") {
                    ubuntuProxy.performHealthCheck()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("🔍 Test Connection") {
                    print(ubuntuProxy.getStatusSummary())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ComponentRow: View {
    let component: uDosComponent
    let status: ProcessStatus?
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onViewLogs: () -> Void
    let onTestConnection: () -> Void

    var body: some View {
        HStack {
            // Icon and name
            HStack(spacing: 8) {
                Text(component.icon)
                Text(component.displayName)
                    .font(.headline)
            }
            
            Spacer()
            
            // Status indicator
            ComponentStatusIndicator(component: component, status: status)
            
            // Controls
            HStack(spacing: 8) {
                if let status = status, status.isRunning {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle")
                            .foregroundColor(.red)
                    }
                    .help("Stop")
                    
                    Button(action: onRestart) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                    }
                    .help("Restart")
                } else {
                    Button(action: onStart) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.green)
                    }
                    .help("Start")
                }
                
                Button(action: onViewLogs) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                }
                .help("View Logs")
                
                if let port = component.port {
                    Button(action: onTestConnection) {
                        Image(systemName: "network")
                            .foregroundColor(.purple)
                    }
                    .help("Test Connection (port \(port))")
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ComponentStatusIndicator: View {
    let component: uDosComponent
    let status: ProcessStatus?

    var body: some View {
        HStack(spacing: 4) {
            if let status = status {
                switch status {
                case .running:
                    Text("🟢 Running")
                        .foregroundColor(.green)
                case .healthy:
                    Text("🟢 Healthy")
                        .foregroundColor(.green)
                case .unhealthy:
                    Text("🟡 Unhealthy")
                        .foregroundColor(.orange)
                case .failed:
                    Text("🔴 Failed")
                        .foregroundColor(.red)
                case .stopped:
                    Text("🟡 Stopped")
                        .foregroundColor(.gray)
                }
            } else {
                Text("🟡 Stopped")
                    .foregroundColor(.gray)
            }
            
            if let port = component.port {
                Text("(\(port))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct uDosComponentView_Previews: PreviewProvider {
    static var previews: some View {
        uDosComponentView()
    }
}
