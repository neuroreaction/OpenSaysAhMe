//
//  OpenSaysAhMeApp.swift
//  OpenSaysAhMe
//
//  Created by on 7/19/23.
//  Updated with Siri Shortcuts + Widget support - November 2025
//

import SwiftUI

@main
struct OpenSaysAhMeApp: App {
    @StateObject private var activityHandler = UserActivityHandler()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activityHandler)
                .onContinueUserActivity("com.garagedoor.open.Right") { activity in
                    activityHandler.handleActivity(activity)
                }
                .onContinueUserActivity("com.garagedoor.open.Left") { activity in
                    activityHandler.handleActivity(activity)
                }
                .onOpenURL { url in
                    handleWidgetURL(url)
                }
        }
    }
    
    private func handleWidgetURL(_ url: URL) {
        guard url.scheme == "opensaysme", url.host == "openmydoor" else { return }
        
        // Get user's preferred door from settings
        let myDoor = UserDefaults.standard.string(forKey: "myDoor") ?? "left"
        let door: GarageDoorAPI.Door = myDoor == "left" ? .left : .right
        
        // Set it as pending so ContentView picks it up
        activityHandler.pendingDoor = door
        
        print("🔗 Widget triggered: Opening \(myDoor) door")
    }
}

// MARK: - User Activity Handler
class UserActivityHandler: ObservableObject {
    @Published var pendingDoor: GarageDoorAPI.Door?
    
    func handleActivity(_ activity: NSUserActivity) {
        print("🎯 Received Siri activity: \(activity.activityType)")
        
        guard let doorString = activity.userInfo?["door"] as? String else {
            print("❌ No door info in activity")
            return
        }
        
        print("🚪 Door to open: \(doorString)")
        
        if let door = GarageDoorAPI.Door(rawValue: doorString) {
            pendingDoor = door
            print("✅ Set pending door to: \(door)")
        }
    }
}
