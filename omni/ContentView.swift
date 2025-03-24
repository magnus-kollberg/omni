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
                
                Text("Omni")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 32)
                
                // Main Options
                VStack(spacing: 16) {
                    NavigationLink {
                        ProvisionView()
                    } label: {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Provision Device")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    NavigationLink {
                        ConfigureView()
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Configure Device")
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
        }
    }
}

struct ConfigureView: View {
    var body: some View {
        Text("Configuration Coming Soon")
            .navigationTitle("Configure Device")
    }
}

#Preview {
    ContentView()
}
