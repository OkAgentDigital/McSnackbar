import Foundation
import Network

/// Bonjour/Zeroconf service discovery for Snackbar.
///
/// Allows multiple Snackbar instances on the same local network to discover
/// each other without hardcoded IP addresses or port conflicts.
///
/// Each Snackbar instance:
///   - Advertises its MCP server (port 8765) via Bonjour as `_snackbar-mcp._tcp`
///   - Advertises its Hivemind gateway (port 3010) via Bonjour as `_snackbar-hive._tcp`
///   - Browses for other Snackbar instances on the network
///
/// Port conflicts are resolved by using the configured port; if two instances
/// on the same machine try to use the same port, the singleton lock prevents it.
/// On different machines, Bonjour ensures they can find each other regardless of IP.
class BonjourService: NSObject, ObservableObject {
    static let shared = BonjourService()
    
    // MARK: - Published State
    
    /// Discovered remote Snackbar instances on the network.
    @Published private(set) var discoveredInstances: [SnackbarPeer] = []
    
    /// Whether Bonjour advertising is active.
    @Published private(set) var isAdvertising: Bool = false
    
    /// Whether Bonjour browsing is active.
    @Published private(set) var isBrowsing: Bool = false
    
    // MARK: - Service Types
    
    private let mcpServiceType = "_snackbar-mcp._tcp"
    private let hiveServiceType = "_snackbar-hive._tcp"
    
    // MARK: - Advertisers (NetService)
    
    private var mcpAdvertiser: NetService?
    private var hiveAdvertiser: NetService?
    
    // MARK: - Browser (NetServiceBrowser)
    
    private var browser: NetServiceBrowser?
    private var resolvedServices: [NetService] = []
    
    // MARK: - Peer Tracking
    
    private var peerMap: [String: SnackbarPeer] = [:]
    
    private override init() {
        super.init()
    }
    
    // MARK: - Advertising
    
    /// Start advertising this Snackbar instance on the network.
    /// - Parameters:
    ///   - mcpPort: The port Snackbar's MCP server is listening on (default: 8765)
    ///   - hivePort: The port HivemindRust is listening on (default: 3010)
    ///   - instanceName: A human-readable name for this instance (default: hostname)
    func startAdvertising(mcpPort: UInt16 = 8765, hivePort: UInt16 = 3010, instanceName: String? = nil) {
        let name = instanceName ?? Host.current().localizedName ?? "Snackbar-\(ProcessInfo.processInfo.processIdentifier)"
        
        // Advertise MCP server
        mcpAdvertiser = NetService(
            domain: "local.",
            type: mcpServiceType,
            name: name,
            port: Int32(mcpPort)
        )
        mcpAdvertiser?.includesPeerToPeer = true
        mcpAdvertiser?.delegate = self
        let mcpTXT: [String: Data] = [
            "hostname": Data((Host.current().localizedName ?? "Snackbar").utf8),
            "version": Data("2.0.0".utf8),
            "mcp_port": Data("\(mcpPort)".utf8),
        ]
        mcpAdvertiser?.setTXTRecord(NetService.data(fromTXTRecord: mcpTXT))
        mcpAdvertiser?.publish()
        
        // Advertise Hivemind gateway
        hiveAdvertiser = NetService(
            domain: "local.",
            type: hiveServiceType,
            name: name,
            port: Int32(hivePort)
        )
        hiveAdvertiser?.includesPeerToPeer = true
        hiveAdvertiser?.delegate = self
        let hiveTXT: [String: Data] = [
            "hostname": Data((Host.current().localizedName ?? "Snackbar").utf8),
            "version": Data("2.0.0".utf8),
            "hive_port": Data("\(hivePort)".utf8),
        ]
        hiveAdvertiser?.setTXTRecord(NetService.data(fromTXTRecord: hiveTXT))
        hiveAdvertiser?.publish()
        
        print("✅ Bonjour: advertising as '\(name)' (MCP: :\(mcpPort), Hive: :\(hivePort))")
    }
    
    /// Stop advertising this instance.
    func stopAdvertising() {
        mcpAdvertiser?.stop()
        mcpAdvertiser = nil
        hiveAdvertiser?.stop()
        hiveAdvertiser = nil
        DispatchQueue.main.async {
            self.isAdvertising = false
        }
        print("🛑 Bonjour: advertising stopped")
    }
    
    // MARK: - Browsing
    
    /// Start browsing for other Snackbar instances on the network.
    func startBrowsing() {
        guard !isBrowsing else { return }
        
        resolvedServices.removeAll()
        
        browser = NetServiceBrowser()
        browser?.includesPeerToPeer = true
        browser?.delegate = self
        browser?.searchForServices(ofType: mcpServiceType, inDomain: "local.")
        
        print("✅ Bonjour: browsing for Snackbar instances...")
    }
    
    /// Stop browsing for other instances.
    func stopBrowsing() {
        browser?.stop()
        browser = nil
        resolvedServices.removeAll()
        DispatchQueue.main.async {
            self.isBrowsing = false
            self.discoveredInstances = []
        }
        print("🛑 Bonjour: browsing stopped")
    }
    
    // MARK: - Resolve a service
    
    private func resolveService(_ service: NetService) {
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }
    
    /// Get the host and port for a discovered peer.
    /// - Parameter peer: The peer to resolve.
    /// - Parameter completion: Called with host string and port, or nil values on failure.
    func resolvePeer(_ peer: SnackbarPeer, completion: @escaping (String?, UInt16?) -> Void) {
        // Find the NetService that matches this peer
        guard let service = resolvedServices.first(where: { $0.name == peer.serviceName }) else {
            completion(nil, nil)
            return
        }
        
        if let host = service.hostName, service.port > 0 {
            completion(host, UInt16(service.port))
        } else {
            // Need to resolve
            service.delegate = self
            service.resolve(withTimeout: 5.0)
            
            // Poll for resolution
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if let host = service.hostName, service.port > 0 {
                    completion(host, UInt16(service.port))
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
}

// MARK: - NetServiceDelegate

extension BonjourService: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isAdvertising = true
        }
        print("✅ Bonjour: published \(sender.type) as '\(sender.name)'")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("⚠️ Bonjour: failed to publish \(sender.type): \(errorDict)")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        print("✅ Bonjour: resolved \(sender.type) '\(sender.name)' → \(sender.hostName ?? "?"):\(sender.port)")
        
        // Parse TXT record for metadata
        var mcpPort: UInt16 = 8765
        var hivePort: UInt16 = 3010
        
        // txtRecordData is an Objective-C nullable property that Swift sees as () -> Data?
        let txtRecordFunc = sender.txtRecordData
        if let txtData = txtRecordFunc() {
            let txt = NetService.dictionary(fromTXTRecord: txtData)
            if let mcpEntry = txt["mcp_port"], let portStr = String(data: mcpEntry, encoding: .utf8), let port = UInt16(portStr) {
                mcpPort = port
            }
            if let hiveEntry = txt["hive_port"], let portStr = String(data: hiveEntry, encoding: .utf8), let port = UInt16(portStr) {
                hivePort = port
            }
        }
        
        let peerID = "\(sender.name).\(sender.type).\(sender.domain)"
        let peer = SnackbarPeer(
            id: peerID,
            name: sender.name,
            serviceName: sender.name,
            type: sender.type,
            domain: sender.domain,
            mcpPort: mcpPort,
            hivePort: hivePort,
            hostName: sender.hostName ?? "localhost",
            port: UInt16(sender.port)
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.peerMap[peerID] = peer
            self.discoveredInstances = Array(self.peerMap.values).sorted { $0.name < $1.name }
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("⚠️ Bonjour: failed to resolve \(sender.type) '\(sender.name)': \(errorDict)")
    }
    
    func netServiceDidStop(_ sender: NetService) {
        print("ℹ️ Bonjour: service stopped: \(sender.type) '\(sender.name)'")
    }
}

// MARK: - NetServiceBrowserDelegate

extension BonjourService: NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        DispatchQueue.main.async {
            self.isBrowsing = true
        }
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        DispatchQueue.main.async {
            self.isBrowsing = false
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("🔍 Bonjour: found service: \(service.type) '\(service.name)'")
        
        // Avoid duplicates
        if !resolvedServices.contains(where: { $0.name == service.name && $0.type == service.type }) {
            resolvedServices.append(service)
            resolveService(service)
        }
        
        if !moreComing {
            DispatchQueue.main.async {
                self.isBrowsing = true
            }
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("👋 Bonjour: service removed: \(service.type) '\(service.name)'")
        
        resolvedServices.removeAll { $0.name == service.name && $0.type == service.type }
        
        let peerID = "\(service.name).\(service.type).\(service.domain)"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.peerMap.removeValue(forKey: peerID)
            self.discoveredInstances = Array(self.peerMap.values).sorted { $0.name < $1.name }
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("⚠️ Bonjour: browser search failed: \(errorDict)")
    }
}

// MARK: - Snackbar Peer

/// Represents a discovered Snackbar instance on the local network.
struct SnackbarPeer: Identifiable, Equatable {
    let id: String
    let name: String
    let serviceName: String
    let type: String
    let domain: String
    let mcpPort: UInt16
    let hivePort: UInt16
    let hostName: String
    let port: UInt16
    
    /// Whether this peer provides an MCP server.
    var hasMCPServer: Bool {
        type.contains("mcp")
    }
    
    /// Whether this peer provides a Hivemind gateway.
    var hasHivemindGateway: Bool {
        type.contains("hive")
    }
    
    /// The URL to connect to this peer's MCP server.
    var mcpURL: String {
        "http://\(hostName):\(mcpPort)"
    }
    
    /// The URL to connect to this peer's Hivemind gateway.
    var hiveURL: String {
        "http://\(hostName):\(hivePort)"
    }
    
    static func == (lhs: SnackbarPeer, rhs: SnackbarPeer) -> Bool {
        lhs.id == rhs.id
    }
}
