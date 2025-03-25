import Foundation
import os.log

@MainActor
class DeviceViewModel: ObservableObject {
    @Published var wifiStatus: String = ""
    @Published var wifiScanResults: String = ""
    @Published var mqttSettings: String = ""
    @Published var telnetSettings: String = ""
    @Published var systemStatus: String = ""
    @Published var error: String?
    @Published var isLoading: Bool = false
    
    let deviceName: String
    let deviceService: DeviceService
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "DeviceViewModel")
    
    init(deviceName: String) {
        self.deviceName = deviceName
        self.deviceService = DeviceService(deviceName: deviceName)
    }
    
    func fetchAllData() async {
        isLoading = true
        error = nil
        
        do {
            async let wifiStatusTask = deviceService.fetchWifiStatus()
            async let wifiScanTask = deviceService.fetchWifiScanResults()
            async let mqttTask = deviceService.fetchMqttSettings()
            async let telnetTask = deviceService.fetchTelnetSettings()
            async let systemTask = deviceService.fetchSystemStatus()
            
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