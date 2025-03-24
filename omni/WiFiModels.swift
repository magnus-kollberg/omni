import Foundation

struct WiFiStatus: Codable {
    let deviceId: String
    let ssid: String
    let rssi: Int
    let localIp: String
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case ssid
        case rssi
        case localIp = "local_ip"
    }
    
    var formattedString: String {
        """
        Device ID: \(deviceId)
        SSID: \(ssid)
        Signal Strength: \(rssi) dBm
        Local IP: \(localIp)
        """
    }
}

struct WiFiNetwork: Codable, Hashable {
    let ssid: String
    let rssi: Int
    
    var formattedString: String {
        "\(ssid) (\(rssi) dBm)"
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(ssid)
        hasher.combine(rssi)
    }
    
    static func == (lhs: WiFiNetwork, rhs: WiFiNetwork) -> Bool {
        lhs.ssid == rhs.ssid && lhs.rssi == rhs.rssi
    }
} 