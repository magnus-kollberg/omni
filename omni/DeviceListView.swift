import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    
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
        .onChange(of: bluetoothManager.connectionStatus) {
            if case .error = bluetoothManager.connectionStatus {
                dismiss()
            }
        }
    }
} 