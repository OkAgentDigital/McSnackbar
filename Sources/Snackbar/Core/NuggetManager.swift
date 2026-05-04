import Foundation

/// Manages Nugget archives (.nug) — compressed, restorable snack archives.
/// Format: gzipped tarball containing snack.yaml, manifest.json, code/, checksum.sha256
class NuggetManager: ObservableObject {
    static let shared = NuggetManager()
    
    @Published private(set) var nuggets: [NuggetInfo] = []
    
    private let fileManager = FileManager.default
    private let nuggetsURL: URL
    
    private init() {
        nuggetsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".nuggets")
        ensureDirectory()
        refresh()
    }
    
    // MARK: - Directory Setup
    
    private func ensureDirectory() {
        if !fileManager.fileExists(atPath: nuggetsURL.path) {
            try? fileManager.createDirectory(at: nuggetsURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Pack
    
    /// Pack a snack into a .nug archive.
    /// - Parameter snackPath: Path to the .snack YAML file
    /// - Returns: Path to the created .nug file, or nil on failure
    func pack(snackPath: String) -> String? {
        let snackURL = URL(fileURLWithPath: snackPath)
        let snackName = snackURL.deletingPathExtension().lastPathComponent
        let nuggetURL = nuggetsURL.appendingPathComponent("\(snackName).nug")
        
        // Read snack YAML
        guard let snackData = try? Data(contentsOf: snackURL),
              let snackContent = String(data: snackData, encoding: .utf8) else {
            print("❌ NuggetManager: Cannot read snack at \(snackPath)")
            return nil
        }
        
        // Create temporary directory for archive contents
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // Write snack.yaml
        let snackYamlURL = tempDir.appendingPathComponent("snack.yaml")
        try? snackContent.write(to: snackYamlURL, atomically: true, encoding: .utf8)
        
        // Create manifest
        let manifest = NuggetManifest(
            original_id: extractSnackId(from: snackContent) ?? snackName,
            original_name: snackName,
            packed_at: SpoolEntry.currentTimestamp(),
            packed_by: NSUserName(),
            version: "1.0.0",
            size_bytes: snackData.count,
            checksum: "sha256:\(snackData.sha256Hex())"
        )
        
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        if let manifestData = try? JSONEncoder().encode(manifest) {
            try? manifestData.write(to: manifestURL)
        }
        
        // Create code directory
        let codeDir = tempDir.appendingPathComponent("code")
        try? fileManager.createDirectory(at: codeDir, withIntermediateDirectories: true)
        
        // Create checksum file
        let checksumURL = tempDir.appendingPathComponent("checksum.sha256")
        try? manifest.checksum.write(to: checksumURL, atomically: true, encoding: .utf8)
        
        // Create gzipped tarball
        let result = createTarGz(from: tempDir, to: nuggetURL)
        
        if result {
            print("✅ NuggetManager: Packed \(snackName) → \(nuggetURL.path)")
            refresh()
        }
        
        return result ? nuggetURL.path : nil
    }
    
    // MARK: - Unpack
    
    /// Unpack a .nug archive back to a .snack file.
    /// - Parameter nuggetId: The nugget ID (filename without .nug)
    /// - Returns: Path to restored .snack file, or nil on failure
    func unpack(nuggetId: String) -> String? {
        let nuggetURL = nuggetsURL.appendingPathComponent("\(nuggetId).nug")
        guard fileManager.fileExists(atPath: nuggetURL.path) else {
            print("❌ NuggetManager: Nugget not found: \(nuggetId)")
            return nil
        }
        
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // Extract tarball
        guard extractTarGz(from: nuggetURL, to: tempDir) else {
            print("❌ NuggetManager: Failed to extract nugget")
            return nil
        }
        
        // Read snack.yaml
        let snackYamlURL = tempDir.appendingPathComponent("snack.yaml")
        guard let snackContent = try? String(contentsOf: snackYamlURL) else {
            print("❌ NuggetManager: No snack.yaml in nugget")
            return nil
        }
        
        // Write to ~/.snacks/
        let snacksDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".snacks")
        try? fileManager.createDirectory(at: snacksDir, withIntermediateDirectories: true)
        let outputURL = snacksDir.appendingPathComponent("\(nuggetId).snack")
        try? snackContent.write(to: outputURL, atomically: true, encoding: .utf8)
        
        print("✅ NuggetManager: Unpacked \(nuggetId) → \(outputURL.path)")
        return outputURL.path
    }
    
    // MARK: - List & Info
    
    /// Refresh the list of nuggets.
    func refresh() {
        guard let files = try? fileManager.contentsOfDirectory(at: nuggetsURL, includingPropertiesForKeys: nil) else {
            nuggets = []
            return
        }
        
        nuggets = files.filter { $0.pathExtension == "nug" }.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int ?? 0
            let modDate = attrs?[.modificationDate] as? Date ?? Date()
            
            // Try to read manifest
            var manifest: NuggetManifest?
            if let tempDir = try? fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true) {
                defer { try? fileManager.removeItem(at: tempDir) }
                if extractTarGz(from: url, to: tempDir) {
                    let manifestURL = tempDir.appendingPathComponent("manifest.json")
                    if let data = try? Data(contentsOf: manifestURL) {
                        manifest = try? JSONDecoder().decode(NuggetManifest.self, from: data)
                    }
                }
            }
            
            return NuggetInfo(
                id: name,
                name: manifest?.original_name ?? name,
                originalId: manifest?.original_id ?? name,
                packedAt: manifest?.packed_at ?? "",
                packedBy: manifest?.packed_by ?? "",
                version: manifest?.version ?? "1.0.0",
                sizeBytes: size,
                checksum: manifest?.checksum ?? ""
            )
        }
    }
    
    /// Get info for a specific nugget.
    func info(nuggetId: String) -> NuggetInfo? {
        refresh()
        return nuggets.first { $0.id == nuggetId }
    }
    
    // MARK: - Helpers
    
    private func extractSnackId(from yaml: String) -> String? {
        for line in yaml.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("id:") {
                return String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    private func createTarGz(from sourceDir: URL, to outputURL: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", outputURL.path, "-C", sourceDir.path, "."]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("❌ NuggetManager: tar error: \(error)")
            return false
        }
    }
    
    private func extractTarGz(from sourceURL: URL, to destDir: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", sourceURL.path, "-C", destDir.path]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("❌ NuggetManager: untar error: \(error)")
            return false
        }
    }
}

// MARK: - Nugget Types

/// Metadata about a nugget archive
struct NuggetInfo: Identifiable, Codable {
    let id: String
    let name: String
    let originalId: String
    let packedAt: String
    let packedBy: String
    let version: String
    let sizeBytes: Int
    let checksum: String
    
    var sizeFormatted: String {
        if sizeBytes < 1024 { return "\(sizeBytes) B" }
        if sizeBytes < 1024 * 1024 { return String(format: "%.1f KB", Double(sizeBytes) / 1024) }
        return String(format: "%.1f MB", Double(sizeBytes) / (1024 * 1024))
    }
}

/// Manifest embedded inside a .nug archive
struct NuggetManifest: Codable {
    let original_id: String
    let original_name: String
    let packed_at: String
    let packed_by: String
    let version: String
    let size_bytes: Int
    let checksum: String
}

// MARK: - Data Extensions

extension Data {
    func sha256Hex() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
