import SwiftUI
import Foundation
import os.log

struct MQTTView: View {
    @StateObject private var restApiModel: RestApiModel
    
    init(deviceName: String) {
        _restApiModel = StateObject(wrappedValue: RestApiModel(deviceName: deviceName))
    }
    
    var body: some View {
        VStack {
            if restApiModel.isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = restApiModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollView {
                    Text(restApiModel.mqttSettings)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
        }
        .task {
            await restApiModel.fetchAllData()
        }
    }
} 