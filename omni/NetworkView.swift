import SwiftUI
import Foundation
import os.log

struct NetworkView: View {
    @StateObject private var viewModel: DeviceViewModel
    @State private var selectedTab = 0
    
    init(deviceName: String) {
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        VStack {
            Picker("Network Info", selection: $selectedTab) {
                Text("WiFi Status").tag(0)
                Text("WiFi Scan").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollView {
                    Text(selectedTab == 0 ? viewModel.wifiStatus : viewModel.wifiScanResults)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
        }
        .task {
            await viewModel.fetchAllData()
        }
    }
} 