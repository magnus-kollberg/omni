import SwiftUI
import Foundation
import os.log

struct SettingsView: View {
    @StateObject private var viewModel: DeviceViewModel
    
    init(deviceName: String) {
        _viewModel = StateObject(wrappedValue: DeviceViewModel(deviceName: deviceName))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollView {
                    Text(viewModel.telnetSettings)
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