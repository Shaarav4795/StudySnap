import Foundation
import SwiftData
import SwiftUI
import Combine
import WidgetKit
import UserNotifications

// MARK: - Widget Data Structure (Shared)

struct WidgetFlashcard: Codable, Identifiable {
    var id: UUID
    var front: String
    var back: String
    var isMastered: Bool
}

struct WidgetStudySet: Codable, Identifiable {
    var id: UUID
    var title: String
    var icon: String
    var flashcards: [WidgetFlashcard]
}

struct WidgetData: Codable {
    var level: Int
    var totalXP: Int
    var xpProgress: Double
    var xpToNextLevel: Int
    var currentStreak: Int
    var coins: Int
    var cardsToReview: Int = 0
    var studySets: [WidgetStudySet] = []
    
    static let placeholder = WidgetData(
        level: 1,
        totalXP: 0,
        xpProgress: 0.0,
        xpToNextLevel: 100,
        currentStreak: 0,
        coins: 100,
        cardsToReview: 0,
        studySets: []
    )
}

// MARK: - Gamification Manager

final class GamificationManager: ObservableObject {
    static let shared = GamificationManager()
    
    @Published var showAchievementUnlocked: Bool = false
    @Published var unlockedAchievement: AchievementType?
    @Published var showXPGained: Bool = false
    @Published var xpGained: Int = 0
    @Published var showLevelUp: Bool = false
    @Published var newLevel: Int = 0
    @Published var showCoinsEarned: Bool = false
    @Published var coinsEarned: Int = 0
    
    private init() {}
    
    // MARK: - Widget Data Sync
    
    func syncStudySets(_ sets: [StudySet]) {
        let widgetSets = sets.map { set in
            WidgetStudySet(
                id: set.id,
                title: set.title,
                icon: set.iconId,
                flashcards: set.flashcards.map { card in
                    WidgetFlashcard(id: card.id, front: card.front, back: card.back, isMastered: card.isMastered)
                }
            )
        }
        
        // Load existing data to preserve other fields
        var widgetData: WidgetData
        if let userDefaults = UserDefaults(suiteName: "group.com.shaarav4795.LearnHub"),
           let data = userDefaults.data(forKey: "widgetData"),
           let existing = try? JSONDecoder().decode(WidgetData.self, from: data) {
            widgetData = existing
            widgetData.studySets = widgetSets
            
            // Update cards to review count
            let cardsToReview = widgetSets.reduce(0) { count, set in
                count + set.flashcards.filter { !$0.isMastered }.count
            }
            widgetData.cardsToReview = cardsToReview
            
        } else {
            // Fallback if no data exists (shouldn't happen if profile exists)
            widgetData = WidgetData.placeholder
            widgetData.studySets = widgetSets
        }
        
        if let userDefaults = UserDefaults(suiteName: "group.com.shaarav4795.LearnHub"),
           let data = try? JSONEncoder().encode(widgetData) {
            userDefaults.set(data, forKey: "widgetData")
            userDefaults.synchronize()
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func updateWidgetData(from profile: UserProfile, studySets: [StudySet]? = nil) {
        // Load existing to preserve sets if not provided
        var currentSets: [WidgetStudySet] = []
        if let userDefaults = UserDefaults(suiteName: "group.com.shaarav4795.LearnHub"),
           let data = userDefaults.data(forKey: "widgetData"),
           let existing = try? JSONDecoder().decode(WidgetData.self, from: data) {
            currentSets = existing.studySets
        }
        
        let setsToSave: [WidgetStudySet]
        if let studySets = studySets {
            setsToSave = studySets.map { set in
                WidgetStudySet(
                    id: set.id,
                    title: set.title,
                    icon: set.iconId,
                    flashcards: set.flashcards.map { card in
                        WidgetFlashcard(id: card.id, front: card.front, back: card.back, isMastered: card.isMastered)
                    }
                )
            }
        } else {
            setsToSave = currentSets
        }
        
        let cardsToReview = setsToSave.reduce(0) { count, set in
            count + set.flashcards.filter { !$0.isMastered }.count
        }
        
        let widgetData = WidgetData(
            level: profile.level,
            totalXP: profile.totalXP,
            xpProgress: profile.xpProgress,
            xpToNextLevel: profile.xpToNextLevel,
            currentStreak: profile.currentStreak,
            coins: profile.coins,
            cardsToReview: cardsToReview,
            studySets: setsToSave
        )
        
        if let userDefaults = UserDefaults(suiteName: "group.com.shaarav4795.LearnHub"),
           let data = try? JSONEncoder().encode(widgetData) {
            userDefaults.set(data, forKey: "widgetData")
            userDefaults.synchronize()
        }
        
        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - User Profile Management
    
    @MainActor
    func getOrCreateProfile(context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? context.fetch(descriptor), let profile = profiles.first {
            updateWidgetData(from: profile)
            return profile
        }
        
        let newProfile = UserProfile()
        context.insert(newProfile)
        try? context.save()
        updateWidgetData(from: newProfile)
        return newProfile
    }
    
    // MARK: - XP & Coins Management
    
    @MainActor
    func addXP(_ amount: Int, to profile: UserProfile, context: ModelContext) {
        let previousLevel = profile.level
        let multiplier = XPRewards.streakMultiplier(for: profile.currentStreak)
        let actualXP = Int(Double(amount) * multiplier)
        
        profile.totalXP += actualXP
        
        // Check for level up
        let newLevelValue = profile.level
        if newLevelValue > previousLevel {
            self.newLevel = newLevelValue
            self.showLevelUp = true
            
            // Check level achievements
            checkLevelAchievements(profile: profile, context: context)
            
            // Auto-dismiss level up notification after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showLevelUp = false
            }
        }
        
        self.xpGained = actualXP
        self.showXPGained = true
        
        try? context.save()
        updateWidgetData(from: profile)
        
        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showXPGained = false
        }
    }
    
    @MainActor
    func addCoins(_ amount: Int, to profile: UserProfile, context: ModelContext) {
        profile.coins += amount
        self.coinsEarned = amount
        self.showCoinsEarned = true
        try? context.save()
        updateWidgetData(from: profile)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showCoinsEarned = false
        }
    }
    
    @MainActor
    func spendCoins(_ amount: Int, from profile: UserProfile, context: ModelContext) -> Bool {
        guard profile.coins >= amount else { return false }
        profile.coins -= amount
        try? context.save()
        updateWidgetData(from: profile)
        return true
    }
    
    // MARK: - Streak Management
    
    @MainActor
    func updateStreak(for profile: UserProfile, context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastStudy = profile.lastStudyDate {
            let lastStudyDay = calendar.startOfDay(for: lastStudy)
            let daysDifference = calendar.dateComponents([.day], from: lastStudyDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                // Already studied today, no change
                return
            } else if daysDifference == 1 {
                // Consecutive day - increase streak
                profile.currentStreak += 1
                if profile.currentStreak > profile.longestStreak {
                    profile.longestStreak = profile.currentStreak
                }
                
                // Daily login bonus
                addXP(XPRewards.dailyLoginBonus + (XPRewards.streakBonus * profile.currentStreak), to: profile, context: context)
                addCoins(CoinRewards.dailyLogin, to: profile, context: context)
                
                // Check streak achievements
                checkStreakAchievements(profile: profile, context: context)
            } else {
                // Streak broken
                profile.currentStreak = 1
                addXP(XPRewards.dailyLoginBonus, to: profile, context: context)
                addCoins(CoinRewards.dailyLogin, to: profile, context: context)
            }
        } else {
            // First study session ever
            profile.currentStreak = 1
            addXP(XPRewards.dailyLoginBonus, to: profile, context: context)
            addCoins(CoinRewards.dailyLogin, to: profile, context: context)
            checkStreakAchievements(profile: profile, context: context)
        }
        
        profile.lastStudyDate = Date()
        try? context.save()
        updateWidgetData(from: profile)

        // Refresh local reminders so we do not ping users right after they already studied
        Task {
            await NotificationManager.shared.refreshStudyReminders(
                lastStudyDate: profile.lastStudyDate,
                streak: profile.currentStreak
            )
        }
    }
    
    // MARK: - Quiz Completion
    
    @MainActor
    func recordQuizCompletion(
        score: Int,
        totalQuestions: Int,
        profile: UserProfile,
        context: ModelContext
    ) {
        // Update stats
        profile.totalQuestionsCorrect += score
        profile.totalQuizzesTaken += 1
        
        let isPerfect = score == totalQuestions && totalQuestions > 0
        if isPerfect {
            profile.perfectQuizzes += 1
        }
        
        // Calculate XP
        var xp = XPRewards.quizCompleted
        xp += score * XPRewards.questionCorrect
        if isPerfect {
            xp += XPRewards.perfectQuiz
        }
        
        addXP(xp, to: profile, context: context)
        
        // Calculate coins
        var coins = CoinRewards.quizCompleted
        if isPerfect {
            coins += CoinRewards.perfectQuiz
        }
        addCoins(coins, to: profile, context: context)
        
        // Update streak
        updateStreak(for: profile, context: context)
        
        // Check achievements
        checkQuestionAchievements(profile: profile, context: context)
        checkPerfectQuizAchievements(profile: profile, context: context)
        
        try? context.save()
    }
    
    // MARK: - Daily Mix Completion
    
    /// Check if Daily Mix was already completed today
    func hasDailyMixCompletedToday(profile: UserProfile) -> Bool {
        guard let lastMixDate = profile.lastDailyMixDate else { return false }
        return Calendar.current.isDateInToday(lastMixDate)
    }
    
    @MainActor
    func recordDailyMixCompletion(
        questionsCorrect: Int,
        flashcardsStudied: Int,
        profile: UserProfile,
        context: ModelContext
    ) {
        // Prevent double rewards on same day
        guard !hasDailyMixCompletedToday(profile: profile) else { return }
        
        // Calculate XP
        var xp = XPRewards.dailyMixBase
        xp += questionsCorrect * XPRewards.dailyMixQuestionCorrect
        xp += flashcardsStudied * XPRewards.dailyMixFlashcard
        
        addXP(xp, to: profile, context: context)
        
        // Calculate coins
        let coins = CoinRewards.dailyMixBase + (questionsCorrect * CoinRewards.dailyMixQuestionCorrect) + (flashcardsStudied * CoinRewards.dailyMixFlashcard)
        addCoins(coins, to: profile, context: context)
        
        // Update streak (Daily Mix counts as study activity)
        updateStreak(for: profile, context: context)
        
        // Mark as completed today
        profile.lastDailyMixDate = Date()
        
        try? context.save()
        updateWidgetData(from: profile)
    }
    
    // MARK: - Flashcard Completion
    
    @MainActor
    func recordFlashcardStudied(
        count: Int,
        mastered: Int,
        profile: UserProfile,
        context: ModelContext
    ) {
        profile.totalFlashcardsStudied += count
        
        var xp = count * XPRewards.flashcardStudied
        xp += mastered * XPRewards.flashcardMastered
        
        addXP(xp, to: profile, context: context)
        
        // Update streak
        updateStreak(for: profile, context: context)
        
        // Check achievements
        checkFlashcardAchievements(profile: profile, context: context)
        
        try? context.save()
    }
    
    // MARK: - Study Set Creation
    
    @MainActor
    func recordStudySetCreated(profile: UserProfile, context: ModelContext) {
        profile.totalStudySets += 1
        
        addXP(XPRewards.studySetCreated, to: profile, context: context)
        addCoins(CoinRewards.studySetCreated, to: profile, context: context)
        
        // Update streak
        updateStreak(for: profile, context: context)
        
        // Check achievements
        checkStudySetAchievements(profile: profile, context: context)
        
        try? context.save()
    }
    
    // MARK: - Achievement Checking
    
    @MainActor
    private func checkQuestionAchievements(profile: UserProfile, context: ModelContext) {
        let milestones: [(Int, AchievementType)] = [
            (5, .questions5),
            (10, .questions10),
            (50, .questions50),
            (100, .questions100),
            (500, .questions500)
        ]
        
        for (threshold, achievement) in milestones {
            if profile.totalQuestionsCorrect >= threshold {
                unlockAchievement(achievement, for: profile, context: context)
            }
        }
    }
    
    @MainActor
    private func checkStreakAchievements(profile: UserProfile, context: ModelContext) {
        let milestones: [(Int, AchievementType)] = [
            (1, .streak1),
            (7, .streak7),
            (14, .streak14),
            (31, .streak31),
            (365, .streak365)
        ]
        
        for (threshold, achievement) in milestones {
            if profile.currentStreak >= threshold {
                unlockAchievement(achievement, for: profile, context: context)
            }
        }
    }
    
    @MainActor
    private func checkStudySetAchievements(profile: UserProfile, context: ModelContext) {
        let milestones: [(Int, AchievementType)] = [
            (1, .studySets1),
            (5, .studySets5),
            (10, .studySets10),
            (25, .studySets25)
        ]
        
        for (threshold, achievement) in milestones {
            if profile.totalStudySets >= threshold {
                unlockAchievement(achievement, for: profile, context: context)
            }
        }
    }
    
    @MainActor
    private func checkFlashcardAchievements(profile: UserProfile, context: ModelContext) {
        let milestones: [(Int, AchievementType)] = [
            (25, .flashcards25),
            (100, .flashcards100),
            (500, .flashcards500)
        ]
        
        for (threshold, achievement) in milestones {
            if profile.totalFlashcardsStudied >= threshold {
                unlockAchievement(achievement, for: profile, context: context)
            }
        }
    }
    
    @MainActor
    private func checkPerfectQuizAchievements(profile: UserProfile, context: ModelContext) {
        let milestones: [(Int, AchievementType)] = [
            (1, .perfectQuiz1),
            (5, .perfectQuiz5),
            (10, .perfectQuiz10)
        ]
        
        for (threshold, achievement) in milestones {
            if profile.perfectQuizzes >= threshold {
                unlockAchievement(achievement, for: profile, context: context)
            }
        }
    }
    
    @MainActor
    private func checkLevelAchievements(profile: UserProfile, context: ModelContext) {
        let milestones: [(Int, AchievementType)] = [
            (5, .level5),
            (10, .level10),
            (25, .level25),
            (50, .level50)
        ]
        
        for (threshold, achievement) in milestones {
            if profile.level >= threshold {
                unlockAchievement(achievement, for: profile, context: context)
            }
        }
    }
    
    // MARK: - Achievement Unlocking
    
    @MainActor
    private func unlockAchievement(_ type: AchievementType, for profile: UserProfile, context: ModelContext) {
        // Check if already unlocked
        if profile.achievements.contains(where: { $0.type == type.rawValue }) {
            return
        }
        
        // Create and save achievement
        let achievement = Achievement(type: type)
        achievement.userProfile = profile
        context.insert(achievement)
        
        // Award XP and coins
        profile.totalXP += type.xpReward
        profile.coins += type.coinReward
        
        try? context.save()
        
        // Show notification
        self.unlockedAchievement = type
        self.showAchievementUnlocked = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showAchievementUnlocked = false
        }
    }
    
    // MARK: - Shop Functions
    
    @MainActor
    func purchaseAvatar(_ avatar: AvatarItem, for profile: UserProfile, context: ModelContext) -> Bool {
        // Check if already owned
        if profile.unlockedItems.contains(where: { $0.itemId == avatar.id && $0.itemType == "avatar" }) {
            return false
        }
        
        // Check level requirement
        guard profile.level >= avatar.requiredLevel else { return false }
        
        // Check coins
        guard spendCoins(avatar.cost, from: profile, context: context) else { return false }
        
        // Unlock item
        let item = UnlockedItem(itemId: avatar.id, itemType: "avatar")
        item.userProfile = profile
        context.insert(item)
        
        try? context.save()
        return true
    }
    
    @MainActor
    func purchaseTheme(_ theme: ThemeItem, for profile: UserProfile, context: ModelContext) -> Bool {
        // Check if already owned
        if profile.unlockedItems.contains(where: { $0.itemId == theme.id && $0.itemType == "theme" }) {
            return false
        }
        
        // Check level requirement
        guard profile.level >= theme.requiredLevel else { return false }
        
        // Check coins
        guard spendCoins(theme.cost, from: profile, context: context) else { return false }
        
        // Unlock item
        let item = UnlockedItem(itemId: theme.id, itemType: "theme")
        item.userProfile = profile
        context.insert(item)
        
        try? context.save()
        return true
    }
    
    @MainActor
    func selectAvatar(_ avatarId: String, for profile: UserProfile, context: ModelContext) -> Bool {
        // Check if owned (default is always owned)
        let isOwned = avatarId == "default_avatar" ||
            profile.unlockedItems.contains(where: { $0.itemId == avatarId && $0.itemType == "avatar" })
        
        guard isOwned else { return false }
        
        profile.selectedAvatarId = avatarId
        try? context.save()
        return true
    }
    
    @MainActor
    func selectTheme(_ themeId: String, for profile: UserProfile, context: ModelContext) -> Bool {
        // Check if owned (default is always owned)
        let isOwned = themeId == "default_theme" ||
            profile.unlockedItems.contains(where: { $0.itemId == themeId && $0.itemType == "theme" })
        
        guard isOwned else { return false }
        
        profile.selectedThemeId = themeId
        try? context.save()
        
        // Update the theme manager
        ThemeManager.shared.updateTheme(for: themeId)
        
        return true
    }
    
    func isItemOwned(_ itemId: String, itemType: String, profile: UserProfile) -> Bool {
        if itemType == "avatar" && itemId == "default_avatar" { return true }
        if itemType == "theme" && itemId == "default_theme" { return true }
        return profile.unlockedItems.contains(where: { $0.itemId == itemId && $0.itemType == itemType })
    }
}

// MARK: - Notification Views

struct AchievementUnlockedView: View {
    let achievement: AchievementType
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: achievement.icon)
                .font(.title)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("+\(achievement.xpReward)")
                        .font(.caption.bold())
                    Text("XP")
                        .font(.caption2)
                }
                .foregroundColor(themeManager.primaryColor)
                
                HStack(spacing: 4) {
                    Text("+\(achievement.coinReward)")
                        .font(.caption.bold())
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption2)
                }
                .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

struct XPGainedView: View {
    let xp: Int
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(themeManager.primaryColor)
            Text("+\(xp) XP")
                .font(.headline)
                .foregroundColor(themeManager.primaryColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(themeManager.primaryColor.opacity(0.2))
        )
    }
}

struct LevelUpView: View {
    let level: Int
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Level Up!")
                .font(.largeTitle.bold())
            
            Text("You reached Level \(level)")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
    }
}

struct CoinsEarnedView: View {
    let coins: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(.yellow)
            Text("+\(coins)")
                .font(.headline)
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.yellow.opacity(0.2))
        )
    }
}
