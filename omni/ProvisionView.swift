import SwiftUI
import CoreBluetooth
import os.log

struct ProvisionView: View {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @State private var showScanner = false
    @State private var showDeviceList = false
    @State private var scannedCode: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isConnecting = false
    @State private var navigateToDeviceStatus = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "ProvisionView")
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 100)
                
                // Main Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Connect with QR Code")
                        }
                        .frame(width: 280)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        bluetoothManager.startScanning()
                        showDeviceList = true
                    }) {
                        HStack {
                            Image(systemName: "bluetooth")
                            Text("Scan for Devices")
                        }
                        .frame(width: 280)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            
            if isConnecting {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Connecting...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
        }
        .navigationTitle("Provision Device")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDeviceList) {
            DeviceListView(bluetoothManager: bluetoothManager)
        }
        .navigationDestination(isPresented: $navigateToDeviceStatus) {
            DeviceStatusView(
                bluetoothManager: bluetoothManager,
                navigationSource: .provision,
                allowDismiss: false
            )
        }
        .sheet(isPresented: $showScanner, onDismiss: {
            scannedCode = nil
        }) {
            ZStack {
                QRScannerView(scannedCode: $scannedCode)
                VStack {
                    Spacer()
                    Text("Align QR code within frame")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 40)
                }
            }
            .onChange(of: scannedCode) { newValue in
                if let code = newValue {
                    handleScannedCode(code)
                }
            }
        }
        .onAppear {
            logger.info("ProvisionView appeared")
        }
        .onDisappear {
            logger.info("ProvisionView disappeared")
        }
        .onChange(of: bluetoothManager.connectionStatus) { status in
            logger.info("Connection status changed to: \(String(describing: status))")
            switch status {
            case .connecting:
                isConnecting = true
            case .error(let message):
                isConnecting = false
                alertMessage = message
                showAlert = true
                showScanner = false
                navigateToDeviceStatus = false
            case .connected:
                isConnecting = false
                navigateToDeviceStatus = true
            case .disconnected:
                isConnecting = false
                if navigateToDeviceStatus {
                    navigateToDeviceStatus = false
                }
            }
        }
        .alert("Connection Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                showAlert = false
                if case .error = bluetoothManager.connectionStatus {
                    bluetoothManager.connectionStatus = .disconnected
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleScannedCode(_ code: String) {
        logger.info("Handling scanned QR code")
        logger.info("QR code scanned: \(code)")
        if code.isEmpty {
            alertMessage = "Invalid QR code"
            showAlert = true
            return
        }
        showScanner = false
        isConnecting = true
        bluetoothManager.connectToDeviceWithIdentifier(code)
    }
}

#Preview {
    NavigationStack {
        ProvisionView()
    }
} 