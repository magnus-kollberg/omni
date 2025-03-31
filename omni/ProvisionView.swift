import SwiftUI
import CoreBluetooth
import os

enum NavigationSource {
    case deviceList
    case provision
}

struct ProvisionView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    let navigationSource: NavigationSource
    let allowDismiss: Bool
    @State private var isNavigatingBack = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "ProvisionView")
    
    init(bluetoothManager: BluetoothManager, navigationSource: NavigationSource, allowDismiss: Bool = true) {
        self.bluetoothManager = bluetoothManager
        self.navigationSource = navigationSource
        self.allowDismiss = allowDismiss
    }
    
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
            logger.info("ProvisionView appeared (source: \(String(describing: navigationSource)))")
            bluetoothManager.startWiFiScan()
            isNavigatingBack = false
        }
        .onDisappear {
            if isNavigatingBack || !allowDismiss {
                logger.info("ProvisionView disappeared - cleaning up connection (source: \(String(describing: navigationSource)))")
                bluetoothManager.disconnect()
                bluetoothManager.connectionStatus = .disconnected
                bluetoothManager.connectedPeripheral = nil
            }
        }
        .onChange(of: presentationMode.wrappedValue.isPresented) { isPresented in
            if !isPresented {
                isNavigatingBack = true
            }
        }
        .toolbar {
            if navigationSource == .provision {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        isNavigatingBack = true
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(!allowDismiss)
    }
}

struct ProvisioningView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNetwork: String?
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isProvisioning = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .info
    @State private var showPassword = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "ProvisioningView")
    
    var body: some View {
        LoadingView(isLoading: $isProvisioning, message: "Setting up device...") {
            Form {
                Section(header: Text("WiFi Networks")) {
                    if bluetoothManager.wifiNetworks.isEmpty {
                        HStack {
                            Text("Scanning for networks...")
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    } else {
                        HStack {
                            Picker("Select Network", selection: $selectedNetwork) {
                                Text("Select a network").tag(Optional<String>.none)
                                ForEach(bluetoothManager.wifiNetworks, id: \.self) { network in
                                    Text(network).tag(Optional(network))
                                }
                            }
                            .accessibilityLabel("WiFi Network Selection")
                            .accessibilityHint("Choose the WiFi network to connect your device to")
                            
                            if let selected = selectedNetwork, !selected.isEmpty {
                                Button(action: {
                                    selectedNetwork = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear selection")
                            }
                        }
                        
                        if selectedNetwork != nil {
                            HStack {
                                Text("Signal strength")
                                Spacer()
                                SignalStrengthIndicator(level: 3) // This should ideally use actual RSSI value
                            }
                        }
                    }
                    
                    Button("Refresh Networks") {
                        withAnimation {
                            bluetoothManager.wifiNetworks.removeAll()
                        }
                        bluetoothManager.startWiFiScan()
                        
                        // Show toast for feedback
                        toastMessage = "Scanning for networks..."
                        toastType = .info
                        showingToast = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Section(header: Text("Password")) {
                    HStack {
                        if showPassword {
                            TextField("WiFi Password", text: $password)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("WiFi Password", text: $password)
                        }
                        
                        Button(action: {
                            showPassword.toggle()
                        }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.blue)
                        }
                    }
                    .accessibilityLabel("WiFi Password")
                    .accessibilityHint("Enter the password for the selected WiFi network")
                }
                
                Section {
                    Button(action: {
                        provisionDevice()
                    }) {
                        HStack {
                            Spacer()
                            Text("Connect Device")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canProvision)
                    .accessibilityLabel("Connect Device")
                    .accessibilityHint("Start configuring this device with the selected WiFi network")
                    
                    if !bluetoothManager.currentProvisioningMessage.isEmpty {
                        Text(bluetoothManager.currentProvisioningMessage)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.top, 4)
                    }
                }
                
                if case .inProgress = bluetoothManager.provisioningStatus {
                    Section {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Connecting device to WiFi...")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Text("This may take a minute")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }
                
                // Help section at the bottom
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("About WiFi Setup")
                                .font(.headline)
                        }
                        
                        Text("Your device needs WiFi to connect to the internet and receive updates. The device will use these credentials to join your home network.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Setup WiFi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logger.info("ProvisioningView tab appeared")
        }
        .onDisappear {
            logger.info("ProvisioningView tab disappeared")
        }
        .onChange(of: bluetoothManager.provisioningStatus) { _ in
            switch bluetoothManager.provisioningStatus {
            case .success:
                isProvisioning = false
                alertMessage = "Device successfully provisioned"
                showAlert = true
                
                // Show success toast
                toastMessage = "Device connected to WiFi!"
                toastType = .success
                showingToast = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    bluetoothManager.disconnect()
                    dismiss()
                }
            case .inProgress:
                isProvisioning = true
            case .failed(let error):
                isProvisioning = false
                alertMessage = "Provisioning failed: \(error)"
                showAlert = true
                
                // Show error toast
                toastMessage = "Connection failed"
                toastType = .error
                showingToast = true
            default:
                isProvisioning = false
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
        .toast(isShowing: $showingToast, message: toastMessage, type: toastType)
    }
    
    private var canProvision: Bool {
        selectedNetwork != nil && !password.isEmpty
    }
    
    private func provisionDevice() {
        guard let ssid = selectedNetwork else { return }
        
        // Set provisioning status to show loading
        isProvisioning = true
        
        // Small delay to ensure UI updates before starting the potentially blocking operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            bluetoothManager.provisionWiFi(ssid: ssid, password: password)
        }
    }
}

struct StatusView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "StatusView")
    
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
        .onAppear {
            logger.info("StatusView tab appeared")
        }
        .onDisappear {
            logger.info("StatusView tab disappeared")
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
    ProvisionView(bluetoothManager: BluetoothManager.shared, navigationSource: .deviceList, allowDismiss: true)
}