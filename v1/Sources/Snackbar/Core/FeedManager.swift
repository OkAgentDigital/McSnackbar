import Foundation

/// Manages execution feed logging and external API integration.
/// v2: Uses SpoolManager for local logging, supports LeChat Pro API for remote logging.
class FeedManager {
    static let shared = FeedManager()
    
    private init() {}
    
    /// Log a snack execution to the feed.
    /// - Parameters:
    ///   - snackName: Name of the executed snack
    ///   - success: Whether execution succeeded
    ///   - output: Execution output text
    func logExecution(snackName: String, success: Bool, output: String) {
        print("📝 Feed: \(snackName) - \(success ? "✅ Success" : "❌ Failed")")
        
        // Send to LeChat Pro API if configured
        if let apiKey = ProcessInfo.processInfo.environment["LECHAT_API_KEY"],
           let apiURL = ProcessInfo.processInfo.environment["LECHAT_API_URL"] {
            sendToLeChatAPI(apiKey: apiKey, apiURL: apiURL, snackName: snackName, success: success, output: output)
        }
    }
    
    private func sendToLeChatAPI(apiKey: String, apiURL: String, snackName: String, success: Bool, output: String) {
        let urlString = "\(apiURL)/log"
        guard let url = URL(string: urlString) else {
            print("❌ FeedManager: Invalid LeChat API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "snackName": snackName,
            "success": success,
            "output": output,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ FeedManager: LeChat API error: \(error.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    print("❌ FeedManager: LeChat API response error: \(httpResponse.statusCode)")
                    return
                }
                print("✅ FeedManager: LeChat API log sent successfully")
            }
            task.resume()
        } catch {
            print("❌ FeedManager: Failed to serialize payload: \(error.localizedDescription)")
        }
    }
}
