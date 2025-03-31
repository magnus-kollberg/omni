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
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastType = .info
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    HStack {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                        Spacer()
                    }
                    .padding(.top)
                    
                    // Welcome section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to Omni")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Connect and configure your IoT devices easily")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                    
                    // Main Options
                    Text("Quick Actions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Provisioning card
                    NavigationLink {
                        BluetoothConnectView()
                    } label: {
                        ActionCard(
                            title: "Provision New Device",
                            subtitle: "Set up a new device with WiFi credentials",
                            systemImage: "wifi",
                            color: .blue
                        )
                    }
                    
                    // Configuration card
                    NavigationLink {
                        ConfigurationView(bluetoothManager: bluetoothManager)
                    } label: {
                        ActionCard(
                            title: "Configure Devices",
                            subtitle: "Update settings on existing devices",
                            systemImage: "gearshape",
                            color: .purple
                        )
                    }
                    
                    // Status section for previously connected devices
                    if let peripheral = bluetoothManager.connectedPeripheral {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connected Device")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ConnectedDeviceCard(peripheral: peripheral)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toast(isShowing: $showingToast, message: toastMessage, type: toastType)
        }
    }
}

// Helper view for action cards
struct ActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(color)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

// Helper view for connected device card
struct ConnectedDeviceCard: View {
    let peripheral: CBPeripheral
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.headline)
                
                Text("Connected")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button(action: {
                BluetoothManager.shared.disconnect()
            }) {
                Text("Disconnect")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
}
