import SwiftUI
import CoreBluetooth
import os

struct BluetoothDiscoveryView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .info
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "BluetoothDiscoveryView")
    
    var filteredDevices: [CBPeripheral] {
        if searchText.isEmpty {
            return bluetoothManager.discoveredDevices
        } else {
            return bluetoothManager.discoveredDevices.filter { 
                ($0.name ?? "Unknown Device").lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack {
            if bluetoothManager.discoveredDevices.isEmpty && bluetoothManager.isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Scanning for devices...")
                        .font(.headline)
                    Text("Make sure your device is in pairing mode")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredDevices.isEmpty && !searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No devices match '\(searchText)'")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bluetoothManager.discoveredDevices.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bluetooth.slash")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No devices found")
                        .font(.headline)
                    Text("Make sure your device is powered on and in pairing mode")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        refreshDevices()
                    }) {
                        Label("Scan Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredDevices, id: \.identifier) { (peripheral: CBPeripheral) in
                    Button(action: {
                        connectToDevice(peripheral)
                    }) {
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "bluetooth")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(peripheral.name ?? "Unknown Device")
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text(peripheral.identifier.uuidString.prefix(8))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
                .searchable(text: $searchText, prompt: "Search devices")
                .refreshable {
                    refreshDevices()
                }
            }
        }
        .navigationTitle("Available Devices")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(bluetoothManager.isScanning ? "Stop" : "Scan") {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                        toastMessage = "Scanning stopped"
                        toastType = .info
                        showingToast = true
                    } else {
                        refreshDevices()
                    }
                }
            }
        }
        .navigationDestination(
            isPresented: .init(
                get: { 
                    bluetoothManager.connectionStatus == .connected && 
                    bluetoothManager.connectedPeripheral != nil
                },
                set: { _ in }
            )
        ) {
            ProvisionView(
                bluetoothManager: bluetoothManager,
                navigationSource: .deviceList
            )
        }
        .onAppear {
            logger.info("BluetoothDiscoveryView appeared")
            if bluetoothManager.discoveredDevices.isEmpty {
                refreshDevices()
            }
        }
        .onDisappear {
            logger.info("BluetoothDiscoveryView disappeared")
        }
        .onChange(of: bluetoothManager.connectionStatus) { status in
            logger.info("Connection status changed to: \(String(describing: status))")
            if case .error = status {
                dismiss()
            }
        }
        .toast(isShowing: $showingToast, message: toastMessage, type: toastType)
    }
    
    private func refreshDevices() {
        bluetoothManager.startScanning()
        toastMessage = "Scanning for devices..."
        toastType = .info
        showingToast = true
    }
    
    private func connectToDevice(_ peripheral: CBPeripheral) {
        toastMessage = "Connecting to \(peripheral.name ?? "device")..."
        toastType = .info
        showingToast = true
        bluetoothManager.connect(to: peripheral)
    }
}

#Preview {
    NavigationStack {
        BluetoothDiscoveryView(bluetoothManager: BluetoothManager.shared)
    }
}