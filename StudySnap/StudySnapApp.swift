//
//  StudySnapApp.swift
//  StudySnap
//
//  Created by Shaarav on 30/11/2025.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct StudySnapApp: App {
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StudySet.self,
            Flashcard.self,
            Question.self,
            UserProfile.self,
            Achievement.self,
            UnlockedItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
        @StateObject private var guideManager = GuideManager.shared
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    init() {
        loadRocketSimConnect()
        // Ensure we don't show an app icon badge: clear any existing badge and
        // register our notification delegate so we can suppress badges when
        // notifications arrive.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // Use modern API to set badge count (iOS 17+)
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Failed to clear badge count: \(error)")
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    
    private func loadRocketSimConnect() {
        #if DEBUG
        if let bundle = Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework"),
           bundle.load() {
            print("RocketSim Connect successfully linked")
        } else {
            print("Failed to load RocketSim Connect linker framework")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gamificationManager)
                .environmentObject(themeManager)
                .environmentObject(guideManager)
                .tint(themeManager.primaryColor)
                .fullScreenCover(isPresented: Binding(
                    get: { !hasSeenTutorial },
                    set: { _ in }
                )) {
                    TutorialView()
                        .environmentObject(themeManager)
                        .environmentObject(guideManager)
                }
                .onChange(of: scenePhase) { newPhase, _ in
                    if newPhase == .active {
                        UNUserNotificationCenter.current().setBadgeCount(0) { error in
                            if let error = error {
                                print("Failed to clear badge count on activate: \(error)")
                            }
                        }
                    }
                }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private override init() { }

    // Present notifications as banners/list with sound, but do not set badges.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
        // Ensure the app icon badge is cleared whenever a notification is shown.
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Clear any badge when the user interacts with the notification.
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        completionHandler()
    }

}


