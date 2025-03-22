//
//  ContentView.swift
//  omni
//
//  Created by Magnus Kollberg on 2025-03-22.
//

import SwiftUI
import CoreBluetooth
import os.log

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @State private var showScanner = false
    @State private var showDeviceList = false
    @State private var scannedCode: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "QRScanner")
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo and Title
                HStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                    Spacer()
                }
                .padding(.bottom, 16)
                
                Text("Omni Provisioning")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 32)
                
                // Main Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Connect with QR Code")
                        }
                        .frame(maxWidth: .infinity)
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
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $showDeviceList) {
                DeviceListView(bluetoothManager: bluetoothManager)
            }
            .navigationDestination(
                isPresented: .init(
                    get: { bluetoothManager.connectionStatus == .connected },
                    set: { _ in }
                )
            ) {
                DeviceStatusView(bluetoothManager: bluetoothManager)
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
            .alert("Connection Error", isPresented: .init(
                get: {
                    if case .error = bluetoothManager.connectionStatus { return true }
                    return showAlert
                },
                set: { showAlert = $0 }
            )) {
                Button("OK", role: .cancel) {
                    showAlert = false
                    if case .error = bluetoothManager.connectionStatus {
                        bluetoothManager.connectionStatus = .disconnected
                    }
                }
            } message: {
                if case .error(let message) = bluetoothManager.connectionStatus {
                    Text(message)
                } else {
                    Text(alertMessage)
                }
            }
        }
    }
    
    private func handleScannedCode(_ code: String) {
        logger.info("QR code scanned: \(code)")
        showScanner = false
        bluetoothManager.connectToDeviceWithIdentifier(code)
    }
}


#Preview {
    ContentView()
}
