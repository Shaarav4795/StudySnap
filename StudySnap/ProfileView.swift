import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var guideManager: GuideManager
    
    @State private var showEditUsername = false
    @State private var newUsername = ""
    @State private var showTutorial = false
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        return gamificationManager.getOrCreateProfile(context: modelContext)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader

                    // Level & XP Progress
                    levelProgressCard

                    // Streak Card (moved up)
                    streakCard

                    // Stats Grid
                    statsGrid

                    // Quick Links
                    quickLinksSection

                    // Small credit text shown only when scrolled to bottom
                    Text("Created with ♡ by Shaarav4795")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticsManager.shared.playTap()
                    showTutorial = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .sheet(isPresented: $showEditUsername) {
            editUsernameSheet
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView()
                .environmentObject(themeManager)
                .environmentObject(guideManager)
        }
        .onAppear {
            if guideManager.currentStep == .openProfile {
                guideManager.advanceAfterOpenedProfile()
            }
        }
        .overlayPreferenceValue(GuideTargetPreferenceKey.self) { prefs in
            GeometryReader { proxy in
                GuideOverlayLayer(
                    guideManager: guideManager,
                    accent: themeManager.primaryColor,
                    prefs: prefs,
                    geometry: proxy,
                    onSkip: { guideManager.skipGuide() },
                    onAdvance: { guideManager.finishGamification() }
                )
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(themeManager.primaryGradient)
                    .frame(width: 100, height: 100)
                
                if let avatar = AvatarItem.avatar(for: profile.selectedAvatarId) {
                    Image(avatar.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                }
            }
            .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Username
            HStack {
                Text(profile.username)
                    .font(.title2.bold())
                
                Button(action: {
                    HapticsManager.shared.playTap()
                    newUsername = profile.username
                    showEditUsername = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            // Level Badge
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Level \(profile.level)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.2))
            )
            
            // Coins Display
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                Text("\(profile.coins)")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                Text("coins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .guideTarget(.profileHeader)
    }
    
    // MARK: - Level Progress Card
    
    private var levelProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Level Progress")
                    .font(.headline)
                Spacer()
                Text("\(profile.totalXP) XP")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.horizontalGradient)
                        .frame(width: geometry.size.width * profile.xpProgress, height: 16)
                }
            }
            .frame(height: 16)
            
            HStack {
                Text("Level \(profile.level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(profile.xpToNextLevel) XP to Level \(profile.level + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                icon: "checkmark.circle.fill",
                color: .green,
                value: "\(profile.totalQuestionsCorrect)",
                label: "Questions Correct"
            )
            
            StatCard(
                icon: "rectangle.stack.fill",
                color: .blue,
                value: "\(profile.totalFlashcardsStudied)",
                label: "Flashcards Studied"
            )
            
            StatCard(
                icon: "doc.text.fill",
                color: .purple,
                value: "\(profile.totalQuizzesTaken)",
                label: "Quizzes Taken"
            )
            
            StatCard(
                icon: "star.fill",
                color: .yellow,
                value: "\(profile.perfectQuizzes)",
                label: "Perfect Scores"
            )
            
            StatCard(
                icon: "book.fill",
                color: .orange,
                value: "\(profile.totalStudySets)",
                label: "Study Sets"
            )
            
            StatCard(
                icon: "trophy.fill",
                color: .yellow,
                value: "\(profile.achievements.count)",
                label: "Achievements"
            )
        }
    }
    
    // MARK: - Streak Card
    
    private var streakCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundColor(profile.currentStreak > 0 ? .orange : .gray)
                
                Text("\(profile.currentStreak)")
                    .font(.title.bold())
                
                Text("Day Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 80)
            
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)
                
                Text("\(profile.longestStreak)")
                    .font(.title.bold())
                
                Text("Best Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Links Section
    
    private var quickLinksSection: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: AchievementsView()) {
                QuickLinkRow(
                    icon: "trophy.fill",
                    color: .yellow,
                    title: "Achievements",
                    subtitle: "\(profile.achievements.count) earned"
                )
            }
            .simultaneousGesture(TapGesture().onEnded { HapticsManager.shared.playTap() })
            
            NavigationLink(destination: ShopView()) {
                QuickLinkRow(
                    icon: "bag.fill",
                    color: .purple,
                    title: "Shop",
                    subtitle: "Avatars & Themes"
                )
            }
            .simultaneousGesture(TapGesture().onEnded { HapticsManager.shared.playTap() })
        }
    }
    
    // MARK: - Edit Username Sheet
    
    private var editUsernameSheet: some View {
        NavigationStack {
            Form {
                Section("Username") {
                    TextField("Enter username", text: $newUsername)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.playTap()
                        showEditUsername = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticsManager.shared.playTap()
                        profile.username = newUsername
                        try? modelContext.save()
                        showEditUsername = false
                    }
                    .disabled(newUsername.isEmpty)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.bold())
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct QuickLinkRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(for: [StudySet.self, UserProfile.self], inMemory: true)
}
