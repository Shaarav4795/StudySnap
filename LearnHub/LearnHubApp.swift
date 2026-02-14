// App entry point and shared SwiftData container setup.

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct LearnHubApp: App {
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StudyFolder.self,
            StudySet.self,
            Flashcard.self,
            Question.self,
            ChatMessage.self,
            UserProfile.self,
            Achievement.self,
            UnlockedItem.self,
        ])
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfiguration])
        } catch {
            print("Initial ModelContainer creation failed: \(error)")

            do {
                let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
            } catch {
                fatalError("Could not recover ModelContainer after resetting store: \(error)")
            }
        }
    }()
    
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
        @StateObject private var guideManager = GuideManager.shared
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    init() {
        loadRocketSimConnect()
        // Disable app icon badges: clear existing badge and set a delegate to suppress badges.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // Use the modern badge API (iOS 17+).
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
                .onAppear {
                    HapticsManager.shared.prepareEngine()
                }
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

    // Present notifications with sound and no badge updates.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
        // Clear the app icon badge whenever a notification is shown.
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Clear any badge when the user interacts with a notification.
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        completionHandler()
    }

}


