import SwiftUI
import CoreBluetooth
import os

struct BluetoothDiscoveryView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "BluetoothDiscoveryView")
    
    var body: some View {
        List(bluetoothManager.discoveredDevices, id: \.identifier) { (peripheral: CBPeripheral) in
            Button(action: {
                bluetoothManager.connect(to: peripheral)
            }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(peripheral.name ?? "Unknown Device")
                            .font(.headline)
                        Text(peripheral.identifier.uuidString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "bluetooth")
                }
            }
        }
        .navigationTitle("Available Devices")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(bluetoothManager.isScanning ? "Stop" : "Scan") {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
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
    }
} 