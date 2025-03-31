//
//  omniApp.swift
//  omni
//
//  Created by Magnus Kollberg on 2025-03-22.
//

import SwiftUI
import UIKit

@main
struct omniApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    
    init() {
        // Request permissions when the app starts
        if #available(iOS 13.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    print("Notification permission granted")
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingCompleted {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}
