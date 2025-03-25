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
        NavigationView {
            DeviceSelectionView(
                networkManager: networkManager,
                selectedDevice: $selectedDevice,
                showDeviceSelection: $showDeviceSelection
            )
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
        List(networkManager.discoveredDevices, id: \.self) { device in
            NavigationLink(destination: TabContentView(
                bluetoothManager: BluetoothManager.shared,
                deviceName: device
            )) {
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

// New view to contain the TabView
struct TabContentView: View {
    let bluetoothManager: BluetoothManager
    let deviceName: String
    
    var body: some View {
        TabView {
            NetworkTabView(bluetoothManager: bluetoothManager, deviceName: deviceName)
                .tabItem {
                    Label("Network", systemImage: "wifi")
                }
            
            MQTTTabView(bluetoothManager: bluetoothManager, deviceName: deviceName, deviceService: DeviceService(deviceName: deviceName))
                .tabItem {
                    Label("MQTT", systemImage: "cloud")
                }
            
            SettingsTabView(bluetoothManager: bluetoothManager, deviceName: deviceName, deviceService: DeviceService(deviceName: deviceName))
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            
            StatusTabView(bluetoothManager: bluetoothManager, deviceName: deviceName)
                .tabItem {
                    Label("Status", systemImage: "info.circle")
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
    @State private var timer: Timer?
    let deviceService: DeviceService
    
    init(bluetoothManager: BluetoothManager, deviceName: String) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
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
                Button("OK") { }
            } message: {
                Text(connectionError ?? "Unknown error occurred")
            }
        }
        .task {
            // Initial load
            await fetchWiFiData()
            
            // Setup auto-refresh timer
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task {
                    await fetchWiFiData()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func fetchWiFiData() async {
        do {
            // Fetch both status and scan results concurrently
            async let statusResponse = deviceService.fetchData(from: "/wifi_fetch_status")
            async let scanResponse = deviceService.fetchData(from: "/wifi_scan_result")
            
            let (status, scan) = try await (statusResponse, scanResponse)
            
            // Parse WiFi Status
            if let statusData = status.data(using: .utf8),
               let newStatus = try? JSONDecoder().decode(WiFiStatus.self, from: statusData) {
                withAnimation(.smooth) {
                    wifiStatus = newStatus
                }
            }
            
            // Parse WiFi Scan Results
            if let scanData = scan.data(using: .utf8),
               let networks = try? JSONDecoder().decode([WiFiNetwork].self, from: scanData) {
                withAnimation(.smooth) {
                    wifiNetworks = networks.sorted { $0.rssi > $1.rssi }
                    
                    // Select the currently connected network if found
                    if let currentSSID = wifiStatus?.ssid {
                        selectedNetwork = wifiNetworks.first { $0.ssid == currentSSID }
                    }
                }
            }
        } catch {
            print("Error fetching WiFi data: \(error)")
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
                    await fetchWiFiData()
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
    @State private var mqttSettings: MQTTSettings?
    @State private var editedServer: String = ""
    @State private var editedPort: String = ""
    @State private var editedUser: String = ""
    @State private var editedPassword: String = ""
    @State private var isSaving: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String?
    let deviceService: DeviceService
    
    init(bluetoothManager: BluetoothManager, deviceName: String, deviceService: DeviceService) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
        self.deviceService = deviceService
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MQTT Settings Section
                Section(header: Text("MQTT Settings")) {
                    LabeledContent("Server") {
                        TextField("mqtt.example.com", text: $editedServer)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    
                    LabeledContent("Port") {
                        TextField("1883", text: $editedPort)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    LabeledContent("Username") {
                        TextField("mqtt_user", text: $editedUser)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    
                    LabeledContent("Password") {
                        SecureField("mqtt_password", text: $editedPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Buttons Section
                Section {
                    // Save Button
                    Button(action: saveSettings) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isSaving || !isValidInput)
                    
                    // Restore Button
                    Button(action: restoreSettings) {
                        Text("Reset to Saved Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.blue)
                    .disabled(isSaving)
                }
            }
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
        }
        .task {
            await fetchMQTTSettings()
        }
    }
    
    private var isValidInput: Bool {
        !editedServer.isEmpty && 
        !editedPort.isEmpty && 
        Int(editedPort) != nil &&
        !editedUser.isEmpty
    }
    
    private func fetchMQTTSettings() async {
        do {
            let response = try await deviceService.fetchData(from: "/mqtt_fetch_settings")
            guard let data = response.data(using: .utf8) else {
                throw URLError(.cannotParseResponse)
            }
            if let settings = try? JSONDecoder().decode(MQTTSettings.self, from: data) {
                mqttSettings = settings
                restoreSettings()
            }
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func restoreSettings() {
        guard let settings = mqttSettings else { return }
        editedServer = settings.server
        editedPort = String(settings.port)
        editedUser = settings.user
        editedPassword = "" // Clear password for security
    }
    
    private func saveSettings() {
        guard let port = Int(editedPort) else { return }
        
        let updatedSettings = [
            "server": editedServer,
            "port": port,
            "user": editedUser,
            "password": editedPassword
        ] as [String : Any]
        
        Task {
            isSaving = true
            
            do {
                try await deviceService.post(endpoint: "/mqtt_update_settings", data: updatedSettings)
                // Refresh settings after successful update
                await fetchMQTTSettings()
            } catch {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
                showErrorAlert = true
            }
            
            isSaving = false
        }
    }
}

struct SettingsTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let deviceName: String
    @StateObject private var viewModel: DeviceViewModel
    @State private var telnetEnabled: Bool = false
    @State private var previousTelnetEnabled: Bool = false
    @State private var isSaving: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String?
    let deviceService: DeviceService
    
    init(bluetoothManager: BluetoothManager, deviceName: String, deviceService: DeviceService) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
        self.deviceService = deviceService
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Debug Settings")) {
                    Toggle("Enable Telnet Server", isOn: $telnetEnabled)
                        .onChange(of: telnetEnabled) { newValue in
                            if newValue != previousTelnetEnabled {
                                previousTelnetEnabled = newValue
                                saveTelnetSettings()
                            }
                        }
                        .disabled(isSaving)
                }
                
                Section {
                    Text("Telnet provides remote command-line access for debugging purposes.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
        }
        .task {
            await fetchTelnetSettings()
        }
    }
    
    private func fetchTelnetSettings() async {
        do {
            let response = try await deviceService.fetchData(from: "/get_telnet")
            guard let data = response.data(using: .utf8) else {
                throw URLError(.cannotParseResponse)
            }
            if let settings = try? JSONDecoder().decode(TelnetSettings.self, from: data) {
                telnetEnabled = settings.enabled
                previousTelnetEnabled = settings.enabled
            }
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func saveTelnetSettings() {
        let settings = [
            "enabled": telnetEnabled ? "true" : "false"
        ] as [String : Any]
        
        Task {
            isSaving = true
            
            do {
                try await deviceService.post(endpoint: "/set_telnet", data: settings)
                // Refresh settings after successful update
                await fetchTelnetSettings()
            } catch {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
                showErrorAlert = true
                // Restore previous state on error
                if let data = viewModel.telnetSettings.data(using: .utf8),
                   let settings = try? JSONDecoder().decode(TelnetSettings.self, from: data) {
                    telnetEnabled = settings.enabled
                }
            }
            
            isSaving = false
        }
    }
}

struct SystemStatus: Codable {
    let current_time: String
    let free_ram: Int
    let used_ram: Int
    let total_ram: Int
    let free_flash: Int
    let used_flash: Int
    let total_flash: Int
    let task_count: Int
}

struct StatusTabView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let deviceName: String
    @StateObject private var viewModel: DeviceViewModel
    @State private var systemStatus: SystemStatus?
    @State private var timer: Timer?
    @State private var showDeviceSelection: Bool = true
    let deviceService: DeviceService
    
    init(bluetoothManager: BluetoothManager, deviceName: String) {
        self.bluetoothManager = bluetoothManager
        self.deviceName = deviceName
        let service = DeviceService(deviceName: deviceName)
        self.deviceService = service
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                } else {
                    // Date Section
                    Section(header: Text("Date & Time")) {
                        Text(systemStatus?.current_time ?? "Loading...")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    // RAM Section
                    Section(header: Text("Memory (RAM)")) {
                        if let status = systemStatus {
                            ProgressView(value: Double(status.used_ram), total: Double(status.total_ram))
                                .tint(.blue)
                                .animation(.smooth, value: status.used_ram)
                            
                            HStack {
                                Text("Used:")
                                Spacer()
                                Text("\(formatBytes(status.used_ram))")
                            }
                            .animation(.none, value: status.used_ram)
                            
                            HStack {
                                Text("Free:")
                                Spacer()
                                Text("\(formatBytes(status.free_ram))")
                            }
                            .animation(.none, value: status.free_ram)
                            
                            HStack {
                                Text("Total:")
                                Spacer()
                                Text("\(formatBytes(status.total_ram))")
                            }
                        }
                    }
                    
                    // File System Section
                    Section(header: Text("File System")) {
                        if let status = systemStatus {
                            ProgressView(value: Double(status.used_flash), total: Double(status.total_flash))
                                .tint(.orange)
                                .animation(.smooth, value: status.used_flash)
                            
                            HStack {
                                Text("Used:")
                                Spacer()
                                Text("\(formatBytes(status.used_flash))")
                            }
                            .animation(.none, value: status.used_flash)
                            
                            HStack {
                                Text("Free:")
                                Spacer()
                                Text("\(formatBytes(status.free_flash))")
                            }
                            .animation(.none, value: status.free_flash)
                            
                            HStack {
                                Text("Total:")
                                Spacer()
                                Text("\(formatBytes(status.total_flash))")
                            }
                        }
                    }
                    
                    // OS Section
                    Section(header: Text("Operating System")) {
                        if let status = systemStatus {
                            HStack {
                                Text("Active Tasks:")
                                Spacer()
                                Text("\(status.task_count)")
                            }
                            .animation(.none, value: status.task_count)
                        }
                    }
                }
            }
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Back") {
                showDeviceSelection = true
            })
        }
        .task {
            // Initial load
            await fetchSystemStatus()
            
            // Setup auto-refresh timer
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task {
                    await fetchSystemStatus()
                }
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func fetchSystemStatus() async {
        do {
            let data = try await deviceService.fetchData(from: "/system_fetch_status")
            if let status = try? JSONDecoder().decode(SystemStatus.self, from: data.data(using: .utf8) ?? Data()) {
                withAnimation {
                    systemStatus = status
                }
            }
        } catch {
            // Handle error silently to avoid disrupting the UI
            print("Error fetching system status: \(error)")
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}

#Preview {
    ConfigurationView(bluetoothManager: BluetoothManager.shared)
} 