import CoreBluetooth
import Combine
import os.log

class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "BluetoothManager")
    
    private var centralManager: CBCentralManager!
    @Published var connectedPeripheral: CBPeripheral?
    @Published var rssi: NSNumber?
    
    @Published var isScanning = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var wifiNetworks: [String] = []
    @Published var provisioningStatus: ProvisioningStatus = .notStarted
    @Published var currentProvisioningMessage: String = ""
    
    // Store the name we're looking for when connecting via QR code
    private var pendingConnectionName: String?
    
    // Service and Characteristic UUIDs
    let targetServiceUUID = CBUUID(string: "021A9004-0382-4AEA-BFF4-6B3F1C5ADFB4")
    let wifiListCharUUID = CBUUID(string: "021AFF53-0382-4AEA-BFF4-6B3F1C5ADFB4")
    let wifiSSIDCharUUID = CBUUID(string: "021AFF50-0382-4AEA-BFF4-6B3F1C5ADFB4")
    let wifiPasswordCharUUID = CBUUID(string: "021AFF51-0382-4AEA-BFF4-6B3F1C5ADFB4")
    let provisioningStatusCharUUID = CBUUID(string: "021AFF52-0382-4AEA-BFF4-6B3F1C5ADFB4")
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    enum ProvisioningStatus: Equatable {
        case notStarted
        case inProgress
        case success
        case failed(String)
        
        static func == (lhs: ProvisioningStatus, rhs: ProvisioningStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notStarted, .notStarted):
                return true
            case (.inProgress, .inProgress):
                return true
            case (.success, .success):
                return true
            case (.failed(let lhsMessage), .failed(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    private override init() {
        super.init()
        logger.info("Initializing BluetoothManager")
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.error("Cannot start scanning - Bluetooth is not powered on")
            connectionStatus = .error("Bluetooth is not powered on")
            return
        }
        logger.info("Starting Bluetooth scan for service UUID: \(self.targetServiceUUID)")
        isScanning = true
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: [targetServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopScanning() {
        logger.info("Stopping Bluetooth scan")
        centralManager.stopScan()
        isScanning = false
        pendingConnectionName = nil
    }
    
    func connect(to peripheral: CBPeripheral) {
        logger.info("Attempting to connect to peripheral: \(peripheral.identifier.uuidString), name: \(peripheral.name ?? "unnamed")")
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionStatus = .connecting
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            logger.info("Disconnecting from peripheral: \(peripheral.identifier.uuidString)")
            centralManager.cancelPeripheralConnection(peripheral)
        }
        provisioningStatus = .notStarted
        currentProvisioningMessage = ""
        pendingConnectionName = nil
    }
    
    func connectToDeviceWithIdentifier(_ identifier: String) {
        logger.info("Attempting to connect to device with name: \(identifier)")
        pendingConnectionName = identifier
        connectionStatus = .connecting  // Set status to connecting immediately
        
        // First check if we've already discovered the device
        if let peripheral = discoveredDevices.first(where: { $0.name == identifier }) {
            logger.info("Found matching peripheral with name: \(identifier) in discovered devices")
            connect(to: peripheral)
            return
        }
        
        // If not found, start scanning for it
        logger.info("Device not found in current list, starting scan for: \(identifier)")
        startScanning()
        
        // Set a timeout for the connection attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self,
                  self.pendingConnectionName == identifier else { return }
            
            // Only show error if we're still looking for this device
            if case .connecting = self.connectionStatus {
                self.logger.error("Connection timeout for device: \(identifier)")
                self.stopScanning()
                self.connectionStatus = .error("Device '\(identifier)' not found. Please make sure the device is powered on and nearby.")
            }
            self.pendingConnectionName = nil
        }
    }
    
    private func startRSSIUpdates() {
        guard let peripheral = connectedPeripheral else { return }
        peripheral.readRSSI()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self,
                  let peripheral = self.connectedPeripheral,
                  case .connected = self.connectionStatus else {
                timer.invalidate()
                return
            }
            peripheral.readRSSI()
        }
    }
    
    func startWiFiScan() {
        guard let peripheral = connectedPeripheral,
              case .connected = connectionStatus else {
            logger.error("Cannot start WiFi scan - not connected")
            return
        }
        
        peripheral.discoverServices([targetServiceUUID])
    }
    
    func provisionWiFi(ssid: String, password: String) {
        guard let peripheral = connectedPeripheral,
              case .connected = connectionStatus else {
            logger.error("Cannot provision WiFi - not connected")
            provisioningStatus = .failed("Not connected to device")
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == targetServiceUUID }),
              let ssidChar = service.characteristics?.first(where: { $0.uuid == wifiSSIDCharUUID }),
              let passwordChar = service.characteristics?.first(where: { $0.uuid == wifiPasswordCharUUID }) else {
            logger.error("Required characteristics not found")
            provisioningStatus = .failed("Device not ready for provisioning")
            return
        }
        
        provisioningStatus = .inProgress
        
        // Write SSID
        let ssidData = Data(ssid.utf8)
        peripheral.writeValue(ssidData, for: ssidChar, type: .withResponse)
        
        // Write password after SSID write completes (handled in delegate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let passwordData = Data(password.utf8)
            peripheral.writeValue(passwordData, for: passwordChar, type: .withResponse)
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.info("Bluetooth is powered on")
        case .poweredOff:
            logger.error("Bluetooth is powered off")
            connectionStatus = .error("Bluetooth is powered off")
        case .unauthorized:
            logger.error("Bluetooth is unauthorized")
            connectionStatus = .error("Bluetooth access is unauthorized")
        case .unsupported:
            logger.error("Bluetooth is unsupported")
            connectionStatus = .error("Bluetooth is not supported")
        default:
            logger.error("Bluetooth is unavailable")
            connectionStatus = .error("Bluetooth is not available")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Only log and add if this is a new device
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            logger.info("Discovered new peripheral - Name: \(peripheral.name ?? "unnamed"), ID: \(peripheral.identifier.uuidString), RSSI: \(RSSI)")
            discoveredDevices.append(peripheral)
            
            // If we're looking for a specific device by name, try to connect
            if let pendingName = pendingConnectionName,
               peripheral.name == pendingName {
                logger.info("Found pending connection device: \(pendingName)")
                stopScanning()
                connect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Successfully connected to peripheral: \(peripheral.identifier.uuidString)")
        connectionStatus = .connected
        provisioningStatus = .notStarted
        currentProvisioningMessage = ""
        startRSSIUpdates()
        stopScanning()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to peripheral: \(peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "unknown error")")
        connectionStatus = .error(error?.localizedDescription ?? "Failed to connect")
        self.connectedPeripheral = nil
        pendingConnectionName = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from peripheral: \(peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "none")")
        connectionStatus = .disconnected
        provisioningStatus = .notStarted
        currentProvisioningMessage = ""
        self.connectedPeripheral = nil
        self.rssi = nil
        pendingConnectionName = nil
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Service discovery failed: \(error.localizedDescription)")
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == targetServiceUUID }) else {
            logger.error("Target service not found")
            return
        }
        
        peripheral.discoverCharacteristics([wifiListCharUUID, wifiSSIDCharUUID, wifiPasswordCharUUID, provisioningStatusCharUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == provisioningStatusCharUUID {
                // Enable notifications for provisioning status
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == wifiListCharUUID {
                // Enable notifications for WiFi list
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Characteristic update failed: \(error.localizedDescription)")
            return
        }
        
        if characteristic.uuid == provisioningStatusCharUUID {
            if let data = characteristic.value,
               let message = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.currentProvisioningMessage = message
                    // Update provisioning status based on the message if needed
                    if message.lowercased().contains("success") {
                        self.provisioningStatus = .success
                    } else if message.lowercased().contains("fail") {
                        self.provisioningStatus = .failed(message)
                    }
                }
            }
        } else if characteristic.uuid == wifiListCharUUID {
            if let data = characteristic.value,
               let networksString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.wifiNetworks = networksString.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Write failed for \(characteristic.uuid): \(error.localizedDescription)")
            provisioningStatus = .failed("Failed to write WiFi credentials")
            return
        }
        
        switch characteristic.uuid {
        case wifiPasswordCharUUID:
            // Password write completed (final step)
            DispatchQueue.main.async {
                self.provisioningStatus = .success
            }
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            logger.error("Failed to read RSSI: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            self.rssi = RSSI
        }
    }
} 