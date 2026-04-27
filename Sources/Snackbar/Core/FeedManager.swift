import Foundation

class FeedManager {
    private let configManager = ConfigManager.shared
    
    func logExecution(_ entry: FeedEntry) {
        // Log to local feed
        print("📝 Logging execution: \(entry.snackName) - \(entry.success ? "Success" : "Failed")")
        
        // Send to LeChat Pro API if enabled
        if configManager.isLeChatEnabled() {
            sendToLeChatAPI(entry: entry)
        }
        
        // In a full implementation, this would:
        // 1. Save to local feed file
        // 2. Send to uDos MCP server if enabled
        // 3. Handle errors gracefully
    }
    
    private func sendToLeChatAPI(entry: FeedEntry) {
        guard let apiKey = configManager.getLeChatAPIKey(),
              let apiURL = configManager.getLeChatAPIURL() else {
            print("❌ LeChat API not configured")
            return
        }
        
        let urlString = "\(apiURL)/log"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid LeChat API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "snackName": entry.snackName,
            "success": entry.success,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ LeChat API error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    print("❌ LeChat API response error: \(httpResponse.statusCode)")
                    return
                }
                
                print("✅ LeChat API log sent successfully")
            }
            
            task.resume()
        } catch {
            print("❌ Failed to serialize LeChat API payload: \(error.localizedDescription)")
        }
    }
}