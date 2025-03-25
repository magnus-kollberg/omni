import SwiftUI
import CoreBluetooth
import os.log
import Combine

struct ConfigurationView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @StateObject private var networkManager = NetworkDeviceManager()
    @State private var selectedDevice: String?
    @State private var showDeviceSelection = true
    
    var body: some View {
        Group {
            if showDeviceSelection {
                DeviceSelectionView(
                    networkManager: networkManager,
                    selectedDevice: $selectedDevice,
                    showDeviceSelection: $showDeviceSelection
                )
            } else {
                TabView {
                    NetworkTabView(bluetoothManager: bluetoothManager, deviceName: selectedDevice ?? "", showDeviceSelection: $showDeviceSelection)
                        .tabItem {
                            Label("Network", systemImage: "wifi")
                        }
                    
                    MQTTTabView(bluetoothManager: bluetoothManager, deviceName: selectedDevice ?? "")
                        .tabItem {
                            Label("MQTT", systemImage: "cloud")
                        }
                    
                    SettingsTabView(bluetoothManager: bluetoothManager, deviceName: selectedDevice ?? "")
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                    
                    StatusTabView(bluetoothManager: bluetoothManager, deviceName: selectedDevice ?? "")
                        .tabItem {
                            Label("Status", systemImage: "info.circle")
                        }
                }
            }
        }
        .onAppear {
            networkManager.startDiscovery()
        }
        .onDisappear {
            networkManager.stopDiscovery()
        }
    }
}

struct DeviceSelectionView: View {
    @ObservedObject var networkManager: NetworkDeviceManager
    @Binding var selectedDevice: String?
    @Binding var showDeviceSelection: Bool
    
    var body: some View {
        NavigationView {
            List(networkManager.discoveredDevices, id: \.self) { device in
                Button(action: {
                    selectedDevice = device
                    showDeviceSelection = false
                }) {
                    HStack {
                        Text(device)
                        Spacer()
                        if selectedDevice == device {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Device")
            .overlay {
                if networkManager.discoveredDevices.isEmpty {
                    VStack {
                        ProgressView()
                        Text("Searching for devices...")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct NetworkTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let deviceName: String
    @StateObject private var viewModel: DeviceViewModel
    @State private var wifiStatus: WiFiStatus?
    @State private var wifiNetworks: [WiFiNetwork] = []
    @State private var selectedNetwork: WiFiNetwork?
    @State private var password: String = ""
    @State private var isConnecting: Bool = false
    @State private var connectionError: String?
    @State private var showErrorAlert: Bool = false
    @Binding var showDeviceSelection: Bool
    let deviceService: DeviceService
    
    init(bluetoothManager: BluetoothManager, deviceName: String, showDeviceSelection: Binding<Bool>) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
        self._showDeviceSelection = showDeviceSelection
        let service = DeviceService(deviceName: deviceName)
        self.deviceService = service
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // WiFi Status Section
                Section(header: Text("WiFi Status")) {
                    if let status = wifiStatus {
                        Text(status.formattedString)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("No WiFi status available")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Network Selection Section
                Section(header: Text("Select Network")) {
                    if wifiNetworks.isEmpty {
                        Text("No networks found")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Network", selection: $selectedNetwork) {
                            Text("Select a network").tag(nil as WiFiNetwork?)
                            ForEach(wifiNetworks, id: \.ssid) { network in
                                HStack {
                                    Text(network.ssid)
                                    Spacer()
                                    Text("\(network.rssi) dBm")
                                        .foregroundColor(signalStrengthColor(rssi: network.rssi))
                                }
                                .tag(network as WiFiNetwork?)
                            }
                        }
                    }
                }
                
                // Password Section
                Section(header: Text("Password")) {
                    SecureField("Enter password", text: $password)
                }
                
                // Connect Button Section
                Section {
                    Button(action: {
                        connectToNetwork()
                    }) {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Connect")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(selectedNetwork == nil || password.isEmpty || isConnecting)
                }
                
                if let error = connectionError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Connection Failed", isPresented: $showErrorAlert) {
                Button("OK") {
                    showDeviceSelection = true
                }
            } message: {
                Text(connectionError ?? "Unknown error occurred")
            }
        }
        .task {
            await viewModel.fetchAllData()
            parseWiFiData()
        }
    }
    
    private func connectToNetwork() {
        guard let network = selectedNetwork else { return }
        
        let credentials = [
            "ssid": network.ssid,
            "password": password
        ]
        
        Task {
            isConnecting = true
            connectionError = nil
            
            do {
                // Set a timeout of 10 seconds
                try await withTimeout(seconds: 10) {
                    try await viewModel.deviceService.post(endpoint: "/wifi_connect", data: credentials)
                    // Refresh all data after successful connection
                    await viewModel.fetchAllData()
                    parseWiFiData()
                }
            } catch {
                connectionError = "Connection failed: \(error.localizedDescription)"
                showErrorAlert = true
            }
            
            isConnecting = false
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func parseWiFiData() {
        // Parse WiFi Status
        if let data = viewModel.wifiStatus.data(using: .utf8),
           let status = try? JSONDecoder().decode(WiFiStatus.self, from: data) {
            wifiStatus = status
        }
        
        // Parse WiFi Scan Results
        if let data = viewModel.wifiScanResults.data(using: .utf8),
           let networks = try? JSONDecoder().decode([WiFiNetwork].self, from: data) {
            wifiNetworks = networks.sorted { $0.rssi > $1.rssi }
            
            // Select the currently connected network if found
            if let currentSSID = wifiStatus?.ssid {
                selectedNetwork = wifiNetworks.first { $0.ssid == currentSSID }
            }
        }
    }
    
    private func signalStrengthColor(rssi: Int) -> Color {
        switch rssi {
        case ..<(-70):
            return .red
        case -70..<(-60):
            return .orange
        case -60..<(-50):
            return .blue
        default:
            return .green
        }
    }
}

struct MQTTTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let deviceName: String
    @StateObject private var viewModel: DeviceViewModel
    
    init(bluetoothManager: BluetoothManager, deviceName: String) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollView {
                        Text(viewModel.mqttSettings)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                }
            }
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.fetchAllData()
        }
    }
}

struct SettingsTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let deviceName: String
    @StateObject private var viewModel: DeviceViewModel
    
    init(bluetoothManager: BluetoothManager, deviceName: String) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollView {
                        Text(viewModel.telnetSettings)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                }
            }
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.fetchAllData()
        }
    }
}

struct StatusTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let deviceName: String
    @StateObject private var viewModel: DeviceViewModel
    
    init(bluetoothManager: BluetoothManager, deviceName: String) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollView {
                        Text(viewModel.systemStatus)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                }
            }
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.fetchAllData()
        }
    }
}

#Preview {
    ConfigurationView(bluetoothManager: BluetoothManager.shared)
} 