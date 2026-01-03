import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let hasAskedKey = "learnhub.notifications.hasAsked"
    private init() {}
    
    private enum Identifier {
        static let morning = "study_reminder_morning"
        static let evening = "study_reminder_evening"
        static let catchUp = "study_reminder_catchup"
    }
    
    enum ReminderAnchor {
        case morning
        case evening
        case catchUp
    }
    
    func bootstrapNotifications(for profile: UserProfile) async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            // Ask once, then stop pestering if the user declines
            if defaults.bool(forKey: hasAskedKey) == false {
                defaults.set(true, forKey: hasAskedKey)
                let granted = await requestAuthorization()
                if granted {
                    await refreshStudyReminders(
                        lastStudyDate: profile.lastStudyDate,
                        streak: profile.currentStreak
                    )
                }
            }
        case .authorized, .provisional, .ephemeral:
            await refreshStudyReminders(
                lastStudyDate: profile.lastStudyDate,
                streak: profile.currentStreak
            )
        default:
            break
        }
    }
    
    func refreshStudyReminders(lastStudyDate: Date?, streak: Int) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else { return }
        
        center.removePendingNotificationRequests(withIdentifiers: [
            Identifier.morning,
            Identifier.evening,
            Identifier.catchUp
        ])
        
        let now = Date()
        let calendar = Calendar.current
        let studiedToday = {
            guard let last = lastStudyDate else { return false }
            return calendar.isDate(last, inSameDayAs: now)
        }()
        
        // Avoid nudging within three hours of a session
        let recencyBuffer: TimeInterval = 3 * 60 * 60
        let lastStudy = lastStudyDate
        
        let morningDate = nextFireDate(
            hour: 8,
            minute: 30,
            jitterMinutes: 20,
            from: now
        )
        let eveningDate = nextFireDate(
            hour: 19,
            minute: 30,
            jitterMinutes: 25,
            from: now
        )
        
        if shouldSchedule(target: morningDate, lastStudy: lastStudy, buffer: recencyBuffer) {
            let content = makeContent(anchor: .morning, streak: streak)
            scheduleNotification(
                id: Identifier.morning,
                fireDate: morningDate,
                content: content
            )
        }
        
        if shouldSchedule(target: eveningDate, lastStudy: lastStudy, buffer: recencyBuffer) {
            let content = makeContent(anchor: .evening, streak: streak)
            scheduleNotification(
                id: Identifier.evening,
                fireDate: eveningDate,
                content: content
            )
        }
        
        // A soft catch-up ping if the user has not studied by mid-afternoon
        if !studiedToday {
            let catchUpBase = calendar.date(bySettingHour: 15, minute: 15, second: 0, of: now) ?? now
            let catchUpDate = nextDate(from: catchUpBase, jitterMinutes: 15, now: now)
            if shouldSchedule(target: catchUpDate, lastStudy: lastStudy, buffer: recencyBuffer) {
                let content = makeContent(anchor: .catchUp, streak: streak)
                scheduleNotification(
                    id: Identifier.catchUp,
                    fireDate: catchUpDate,
                    content: content
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func requestAuthorization() async -> Bool {
        do {
            // Don't request badge permission so the app won't show an icon badge automatically.
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }
    
    private func makeContent(anchor: ReminderAnchor, streak: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let streakNote: String
        if streak >= 7 {
            streakNote = "Streak \(streak) days strong. Keep it going!"
        } else if streak >= 3 {
            streakNote = "You are on a \(streak)-day streak."
        } else {
            streakNote = "Today is a good day to build momentum."
        }
        
        switch anchor {
        case .morning:
            content.title = "Plan a 10 minute study block"
            content.body = "Set up one quick session before the day gets busy. \(streakNote)"
        case .evening:
            content.title = "Wrap up with a quick review"
            content.body = "A short set now locks in today’s streak. \(streakNote)"
        case .catchUp:
            content.title = "Still time to study today"
            content.body = "One focused session will keep you on track. \(streakNote)"
        }
        content.sound = .default
        return content
    }
    
    private func nextFireDate(hour: Int, minute: Int, jitterMinutes: Int, from now: Date) -> Date {
        let calendar = Calendar.current
        let jitter = Int.random(in: 0...max(jitterMinutes, 0))
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute + jitter
        components.second = 0
        var candidate = calendar.date(from: components) ?? now
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
    
    private func nextDate(from base: Date, jitterMinutes: Int, now: Date) -> Date {
        let calendar = Calendar.current
        let jitter = Int.random(in: 0...max(jitterMinutes, 0))
        var date = calendar.date(byAdding: .minute, value: jitter, to: base) ?? base
        if date <= now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }
    
    private func scheduleNotification(id: String, fireDate: Date, content: UNMutableNotificationContent) {
        let calendar = Calendar.current
        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
    
    private func shouldSchedule(target: Date, lastStudy: Date?, buffer: TimeInterval) -> Bool {
        guard let last = lastStudy else { return true }
        return abs(target.timeIntervalSince(last)) > buffer
    }
}
