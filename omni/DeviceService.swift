import Foundation
import os.log

class DeviceService {
    private let baseURL: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "DeviceService")
    
    init(deviceName: String) {
        // Construct the base URL from the device name
        self.baseURL = "http://\(deviceName).local"
    }
    
    func fetchData(from endpoint: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return jsonString
    }
    
    // Network endpoints
    func fetchWifiStatus() async throws -> String {
        return try await fetchData(from: "/wifi_fetch_status")
    }
    
    func fetchWifiScanResults() async throws -> String {
        return try await fetchData(from: "/wifi_scan_result")
    }
    
    // MQTT endpoints
    func fetchMqttSettings() async throws -> String {
        return try await fetchData(from: "/mqtt_fetch_settings")
    }
    
    // Settings endpoints
    func fetchTelnetSettings() async throws -> String {
        return try await fetchData(from: "/get_telnet")
    }
    
    // Status endpoints
    func fetchSystemStatus() async throws -> String {
        return try await fetchData(from: "/system_fetch_status")
    }
} 