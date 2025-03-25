import Foundation
import os.log

class DeviceService {
    private let baseURL: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "DeviceService")
    
    init(deviceName: String) {
        // Construct the base URL from the device name
        self.baseURL = "http://\(deviceName).local"
        logger.info("Initializing DeviceService with base URL: \(self.baseURL)")
    }
    
    func fetchData(from endpoint: String) async throws -> String {
        guard let url = URL(string: "\(self.baseURL)\(endpoint)") else {
            logger.error("Invalid URL constructed: \(self.baseURL)\(endpoint)")
            throw URLError(.badURL)
        }
        
        logger.info("Fetching data from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type received")
                throw URLError(.badServerResponse)
            }
            
            guard httpResponse.statusCode == 200 else {
                logger.error("Received non-200 status code: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                logger.error("Failed to decode response data as UTF-8")
                throw URLError(.cannotDecodeContentData)
            }
            
            logger.info("Successfully fetched data from \(endpoint)")
            return jsonString
        } catch let error as URLError {
            switch error.code {
            case .cannotFindHost:
                logger.error("Cannot find host: \(self.baseURL) - Check if device is on the same network and mDNS is working")
            case .timedOut:
                logger.error("Request timed out for \(self.baseURL) - Network might be slow or device might be unreachable")
            case .networkConnectionLost:
                logger.error("Network connection lost while connecting to \(self.baseURL)")
            default:
                logger.error("URL error: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    func post(endpoint: String, data: [String: Any]) async throws {
        guard let url = URL(string: "\(self.baseURL)\(endpoint)") else {
            logger.error("Invalid URL constructed: \(self.baseURL)\(endpoint)")
            throw URLError(.badURL)
        }
        
        logger.info("Posting data to: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Convert dictionary to form-urlencoded string
        let formData = data.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? String(describing: value)
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        request.httpBody = formData.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response type received")
                throw URLError(.badServerResponse)
            }
            
            guard httpResponse.statusCode == 200 else {
                logger.error("Received non-200 status code: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            logger.info("Successfully posted data to \(endpoint)")
        } catch let error as URLError {
            switch error.code {
            case .cannotFindHost:
                logger.error("Cannot find host: \(self.baseURL) - Check if device is on the same network and mDNS is working")
            case .timedOut:
                logger.error("Request timed out for \(self.baseURL) - Network might be slow or device might be unreachable")
            case .networkConnectionLost:
                logger.error("Network connection lost while connecting to \(self.baseURL)")
            default:
                logger.error("URL error: \(error.localizedDescription)")
            }
            throw error
        }
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