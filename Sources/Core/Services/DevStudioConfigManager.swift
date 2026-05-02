// DevStudioConfigManager.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation

public struct DevStudioConfig: Codable {
    public var icloudSync: Bool
    public var vaultPath: String
    public var notifications: [NotificationConfig]
    public var skills: [SkillConfig]

    public struct NotificationConfig: Codable {
        public var type: String
        public var trigger: String
        public var enabled: Bool
    }

    public struct SkillConfig: Codable {
        public var name: String
        public var enabled: Bool
        public var args: [String]?
    }

    public init(icloudSync: Bool = true, vaultPath: String = "~/Vault/notes/", notifications: [NotificationConfig] = [], skills: [SkillConfig] = []) {
        self.icloudSync = icloudSync
        self.vaultPath = vaultPath
        self.notifications = notifications
        self.skills = skills
    }
}

public class DevStudioConfigManager {
    public static let shared = DevStudioConfigManager()
    
    private let snackbarConfigPath: String
    private let devStudioConfigPath: String
    
    public init(snackbarConfigPath: String = "~/.config/udos/snackbar.yaml", devStudioConfigPath: String = "~/Code/DevStudio/configs/snackbar.yaml") {
        self.snackbarConfigPath = snackbarConfigPath
        self.devStudioConfigPath = devStudioConfigPath
    }

    // MARK: - Load Config
    public func loadConfig(from path: String? = nil, completion: @escaping (Result<DevStudioConfig, Error>) -> Void) {
        let configPath = path ?? snackbarConfigPath
        let expandedPath = (configPath as NSString).expandingTildeInPath
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            let config = try JSONDecoder().decode(DevStudioConfig.self, from: data)
            completion(.success(config))
        } catch {
            // Return default config if file doesn't exist or can't be decoded
            completion(.success(DevStudioConfig()))
        }
    }

    // MARK: - Save Config
    public func saveConfig(_ config: DevStudioConfig, to path: String? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
        let configPath = path ?? snackbarConfigPath
        let expandedPath = (configPath as NSString).expandingTildeInPath
        
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: URL(fileURLWithPath: expandedPath), options: [.atomicWrite])
            completion(.success(true))
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Sync Configs
    public func syncConfigs(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Load from DevStudio
        loadConfig(from: devStudioConfigPath) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let devStudioConfig):
                // Save to Snackbar
                self.saveConfig(devStudioConfig, to: self.snackbarConfigPath) { result in
                    switch result {
                    case .success:
                        completion(.success(true))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Update Config
    public func updateConfig(_ updates: (inout DevStudioConfig) -> Void, completion: @escaping (Result<DevStudioConfig, Error>) -> Void) {
        loadConfig { result in
            switch result {
            case .success(var config):
                updates(&config)
                
                self.saveConfig(config) { saveResult in
                    switch saveResult {
                    case .success:
                        completion(.success(config))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}