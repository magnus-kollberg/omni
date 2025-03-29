import Foundation
import os.log

@MainActor
class RestApiModel: ObservableObject {
    @Published var wifiStatus: String = ""
    @Published var wifiScanResults: String = ""
    @Published var mqttSettings: String = ""
    @Published var telnetSettings: String = ""
    @Published var systemStatus: String = ""
    @Published var error: String?
    @Published var isLoading: Bool = false
    
    let deviceName: String
    let restApiService: RestApiService
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "RestApiModel")
    
    init(deviceName: String) {
        self.deviceName = deviceName
        self.restApiService = RestApiService(deviceName: deviceName)
    }
    
    func fetchAllData() async {
        isLoading = true
        error = nil
        
        do {
            async let wifiStatusTask = restApiService.fetchWifiStatus()
            async let wifiScanTask = restApiService.fetchWifiScanResults()
            async let mqttTask = restApiService.fetchMqttSettings()
            async let telnetTask = restApiService.fetchTelnetSettings()
            async let systemTask = restApiService.fetchSystemStatus()
            
            let (wifiStatus, wifiScan, mqtt, telnet, system) = try await (wifiStatusTask, wifiScanTask, mqttTask, telnetTask, systemTask)
            
            self.wifiStatus = wifiStatus
            self.wifiScanResults = wifiScan
            self.mqttSettings = mqtt
            self.telnetSettings = telnet
            self.systemStatus = system
        } catch {
            self.error = "Failed to fetch device data: \(error.localizedDescription)"
            logger.error("Error fetching device data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
} 