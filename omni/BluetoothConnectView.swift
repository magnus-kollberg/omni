import SwiftUI
import CoreBluetooth
import os.log

struct BluetoothConnectView: View {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @State private var showScanner = false
    @State private var showDeviceList = false
    @State private var scannedCode: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isConnecting = false
    @State private var navigateToProvision = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .info
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "BluetoothConnectView")
    
    var body: some View {
        LoadingView(isLoading: $isConnecting, message: "Connecting to device...") {
            VStack(spacing: 24) {
                // Header section
                VStack(spacing: 12) {
                    Image(systemName: "bluetooth.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    
                    Text("Connect to Device")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Select a method to connect to your IoT device")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityLabel("You can connect using a QR code or by scanning for nearby devices")
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Connection options
                VStack(spacing: 20) {
                    Button(action: {
                        showScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text("Scan QR Code")
                                    .font(.headline)
                                
                                Text("Quickly connect with a QR code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Connect with QR code")
                    .accessibilityHint("Opens the camera to scan a QR code")
                    
                    Button(action: {
                        bluetoothManager.startScanning()
                        showDeviceList = true
                    }) {
                        HStack {
                            Image(systemName: "bluetooth")
                                .font(.title2)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text("Browse Nearby Devices")
                                    .font(.headline)
                                
                                Text("Scan for available Bluetooth devices")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scan for devices")
                    .accessibilityHint("Shows a list of nearby Bluetooth devices")
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Help text
                VStack {
                    if let peripheral = bluetoothManager.connectedPeripheral {
                        Text("Currently connected to: \(peripheral.name ?? "Unknown Device")")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding()
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Make sure your device is in pairing mode")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("Connect Device")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDeviceList) {
            BluetoothDiscoveryView(bluetoothManager: bluetoothManager)
        }
        .navigationDestination(isPresented: $navigateToProvision) {
            ProvisionView(
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
                        .font(.headline)
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
            logger.info("BluetoothConnectView appeared")
        }
        .onDisappear {
            logger.info("BluetoothConnectView disappeared")
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
                navigateToProvision = false
                
                // Show toast for error too
                toastMessage = "Connection failed: \(message)"
                toastType = .error
                showingToast = true
            case .connected:
                isConnecting = false
                navigateToProvision = true
                
                // Show toast for successful connection
                toastMessage = "Connected successfully"
                toastType = .success
                showingToast = true
            case .disconnected:
                isConnecting = false
                if navigateToProvision {
                    navigateToProvision = false
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
        .toast(isShowing: $showingToast, message: toastMessage, type: toastType)
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
        BluetoothConnectView()
    }
}