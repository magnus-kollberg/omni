import SwiftUI
import CoreBluetooth

struct DeviceStatusView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            ProvisioningView(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("Provision", systemImage: "wifi")
                }
            
            StatusView(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("Status", systemImage: "info.circle")
                }
        }
        .onAppear {
            bluetoothManager.startWiFiScan()
        }
        .onDisappear {
            bluetoothManager.disconnect()
        }
    }
}

struct ProvisioningView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNetwork: String?
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("WiFi Networks")) {
                if bluetoothManager.wifiNetworks.isEmpty {
                    Text("No WiFi networks available")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Select Network", selection: $selectedNetwork) {
                        Text("Select a network").tag(Optional<String>.none)
                        ForEach(bluetoothManager.wifiNetworks, id: \.self) { network in
                            Text(network).tag(Optional(network))
                        }
                    }
                }
            }
            
            Section(header: Text("Password")) {
                SecureField("WiFi Password", text: $password)
            }
            
            Section {
                Button("Provision") {
                    provisionDevice()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProvision ? Color.blue : Color.blue.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!canProvision)
                
                if !bluetoothManager.currentProvisioningMessage.isEmpty {
                    Text(bluetoothManager.currentProvisioningMessage)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding(.top, 4)
                }
            }
            
            if case .inProgress = bluetoothManager.provisioningStatus {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Provisioning...")
                        Spacer()
                    }
                }
            }
        }
        .onChange(of: bluetoothManager.provisioningStatus) { _ in
            switch bluetoothManager.provisioningStatus {
            case .success:
                alertMessage = "Device successfully provisioned"
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    bluetoothManager.disconnect()
                    dismiss()
                }
            case .failed(let error):
                alertMessage = "Provisioning failed: \(error)"
                showAlert = true
            default:
                break
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }
    
    private var canProvision: Bool {
        selectedNetwork != nil && !password.isEmpty
    }
    
    private func provisionDevice() {
        guard let ssid = selectedNetwork else { return }
        bluetoothManager.provisionWiFi(ssid: ssid, password: password)
    }
}

struct StatusView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        List {
            Section("Connection Status") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(statusColor)
                }
                
                if let peripheral = bluetoothManager.connectedPeripheral {
                    HStack {
                        Text("Device Name")
                        Spacer()
                        Text(peripheral.name ?? "Unknown")
                    }
                    
                    HStack {
                        Text("Identifier")
                        Spacer()
                        Text(peripheral.identifier.uuidString)
                            .font(.caption)
                    }
                    
                    if let rssi = bluetoothManager.rssi {
                        HStack {
                            Text("Signal Strength")
                            Spacer()
                            Text("\(rssi) dBm")
                        }
                    }
                }
            }
            
            Section {
                Button("Disconnect", role: .destructive) {
                    bluetoothManager.disconnect()
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch bluetoothManager.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch bluetoothManager.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

#Preview {
    DeviceStatusView(bluetoothManager: BluetoothManager.shared)
} 