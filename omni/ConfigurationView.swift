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
                    NetworkTabView(bluetoothManager: bluetoothManager, deviceName: selectedDevice ?? "")
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
                    TabView {
                        ScrollView {
                            Text(viewModel.wifiStatus)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                        }
                        .tabItem {
                            Label("WiFi Status", systemImage: "wifi")
                        }
                        
                        ScrollView {
                            Text(viewModel.wifiScanResults)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                        }
                        .tabItem {
                            Label("WiFi Scan", systemImage: "list.bullet")
                        }
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