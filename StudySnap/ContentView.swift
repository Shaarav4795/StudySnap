//
//  ContentView.swift
//  StudySnap
//
//  Created by Shaarav on 30/11/2025.
//

import SwiftUI
import SwiftData

// MARK: - Tab Enum
enum AppTab: Int, CaseIterable {
    case shop = 0
    case achievements = 1
    case home = 2
    case profile = 3
    case settings = 4
    
    var title: String {
        switch self {
        case .shop: return "Shop"
        case .achievements: return "Achievements"
        case .home: return "Home"
        case .profile: return "Profile"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .shop: return "bag.fill"
        case .achievements: return "trophy.fill"
        case .home: return "house.fill"
        case .profile: return "person.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudySet.dateCreated, order: .reverse) private var studySets: [StudySet]
    @Query(sort: \StudyFolder.dateCreated, order: .reverse) private var studyFolders: [StudyFolder]
    @Query private var profiles: [UserProfile]
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var guideManager: GuideManager
    @State private var isShowingInputSheet = false
    @State private var isShowingCreateFolderSheet = false
    @State private var folderToEdit: StudyFolder? = nil
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var setToRename: StudySet? = nil
    @State private var isShowingRenameSheet: Bool = false
    @State private var renameTitle: String = ""
    @State private var renameIconId: String = "book"
    @State private var setMovingToFolder: StudySet? = nil
    @State private var isShowingMoveToFolderSheet: Bool = false
    @State private var hasRequestedNotifications = false
    @State private var navigationPath = NavigationPath()
    @State private var isShowingDailyMix = false
    @State private var isFoldersExpanded = true
    @State private var isStudySetsExpanded = true
    @State private var selectedTab: AppTab = .home
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        return gamificationManager.getOrCreateProfile(context: modelContext)
    }

    private var filteredStudySets: [StudySet] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return studySets.filter { $0.folder == nil }
        }
        return studySets.filter { set in
            set.title.range(of: text, options: .caseInsensitive) != nil
            || (set.summary?.range(of: text, options: .caseInsensitive) != nil)
            || (set.originalText.range(of: text, options: .caseInsensitive) != nil)
        }
    }
    
    private var filteredFolders: [StudyFolder] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return studyFolders
        }
        return studyFolders.filter { folder in
            folder.name.range(of: text, options: .caseInsensitive) != nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Shop Tab
            NavigationStack {
                ShopView()
            }
            .tabItem {
                Label(AppTab.shop.title, systemImage: AppTab.shop.icon)
            }
            .tag(AppTab.shop)
            
            // Achievements Tab
            NavigationStack {
                AchievementsView()
            }
            .tabItem {
                Label(AppTab.achievements.title, systemImage: AppTab.achievements.icon)
            }
            .tag(AppTab.achievements)
            
            // Home Tab (center, default)
            homeView
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)
            
            // Profile Tab
            NavigationStack {
                ProfileView()
                    .environmentObject(guideManager)
            }
            .tabItem {
                Label(AppTab.profile.title, systemImage: AppTab.profile.icon)
            }
            .tag(AppTab.profile)
            
            // Settings Tab
            NavigationStack {
                ModelSettingsView()
                    .environmentObject(guideManager)
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
            }
            .tag(AppTab.settings)
        }
        .tint(themeManager.primaryColor)
        .onAppear {
            themeManager.updateTheme(for: profile.selectedThemeId)
        }
        .onChange(of: profile.selectedThemeId) { _, newValue in
            themeManager.updateTheme(for: newValue)
        }
        .onChange(of: studySets) { _, newSets in
            gamificationManager.syncStudySets(newSets)
        }
        .onAppear {
            gamificationManager.syncStudySets(studySets)
        }
        .overlay(alignment: .top) {
            // Achievement notification overlay
            if gamificationManager.showAchievementUnlocked && !isSearching, let achievement = gamificationManager.unlockedAchievement {
                AchievementUnlockedView(achievement: achievement)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                    .padding(.top, 50)
            }
        }
        .overlay(alignment: .top) {
            // Level up notification
            if gamificationManager.showLevelUp && !isSearching {
                LevelUpView(level: gamificationManager.newLevel)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(101)
                    .padding(.top, 100)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: (gamificationManager.showAchievementUnlocked && !isSearching))
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: (gamificationManager.showLevelUp && !isSearching))
        .task {
            guard hasRequestedNotifications == false else { return }
            hasRequestedNotifications = true
            await NotificationManager.shared.bootstrapNotifications(for: profile)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "studysnap" else { return }
        
        if url.host == "flashcards", let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            if let setIDString = components.queryItems?.first(where: { $0.name == "setID" })?.value,
               let setID = UUID(uuidString: setIDString),
               let set = studySets.first(where: { $0.id == setID }) {
                selectedTab = .home
                navigationPath.append(set)
            }
        } else if url.host == "stats" {
            // Navigate to profile tab for stats
            selectedTab = .profile
        }
    }
    
    // MARK: - Home View
    private var homeView: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if studySets.isEmpty && studyFolders.isEmpty && searchText.isEmpty {
                    VStack(spacing: 16) {
                        // Daily Mix Card
                        dailyMixCard
                        
                        // Gamification Header Card (scrolls with content)
                        gamificationHeader

                        Spacer()

                        ContentUnavailableView {
                            Label("No Study Sets", systemImage: "books.vertical")
                        } description: {
                            Text("Tap the + button to create your first study set.")
                        }

                        Spacer()
                    }
                } else if filteredStudySets.isEmpty && filteredFolders.isEmpty {
                    VStack(spacing: 16) {
                        // Daily Mix Card
                        dailyMixCard
                        
                        // Keep the gamification header visible when searching
                        gamificationHeader

                        Spacer()

                        ContentUnavailableView {
                            Label("No Results", systemImage: "magnifyingglass")
                        } description: {
                            Text("No study sets match \"\(searchText)\".")
                        }

                        Spacer()
                    }
                } else {
                    List {
                        // Daily Mix Card as first item
                        Section {
                            dailyMixCard
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                        .listRowSeparator(.hidden)
                        
                        // Gamification Header as second item in list
                        Section {
                            gamificationHeader
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                        .listRowSeparator(.hidden)
                        
                        // Folders Section
                        if !filteredFolders.isEmpty {
                            Section {
                                // Folders Header (scrolls with content)
                                Button(action: {
                                    withAnimation {
                                        isFoldersExpanded.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text("Folders")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .rotationEffect(.degrees(isFoldersExpanded ? 90 : 0))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)

                                if isFoldersExpanded {
                                    // Adaptive grid that scales with screen size
                                    let columns = [
                                        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)
                                    ]

                                    LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                                        ForEach(filteredFolders) { folder in
                                            Button {
                                                navigationPath.append(folder)
                                            } label: {
                                                FolderCard(folder: folder)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(RoundedRectangle(cornerRadius: 18))
                                            .overlay(alignment: .topTrailing) {
                                                Menu {
                                                    Button {
                                                        folderToEdit = folder
                                                        isShowingCreateFolderSheet = true
                                                    } label: {
                                                        Label("Rename", systemImage: "pencil")
                                                    }

                                                    Button(role: .destructive) {
                                                        withAnimation {
                                                            modelContext.delete(folder)
                                                        }
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis.circle")
                                                        .font(.title3)
                                                        .foregroundColor(.secondary)
                                                        .padding(8)
                                                }
                                                .contentShape(Rectangle())
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 20)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }

                        if !filteredStudySets.isEmpty {
                            Section {
                                // Study Sets Header (only show if folders exist)
                                if !filteredFolders.isEmpty {
                                    Button(action: {
                                        withAnimation {
                                            isStudySetsExpanded.toggle()
                                        }
                                    }) {
                                        HStack {
                                            Text("Study Sets")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .rotationEffect(.degrees(isStudySetsExpanded ? 90 : 0))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                                
                                if isStudySetsExpanded {
                                    ForEach(filteredStudySets) { set in
                                    ZStack {
                                        NavigationLink(value: set) {
                                            EmptyView()
                                        }
                                        .opacity(0)
                                        
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: set.icon.systemName)
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(Circle().fill(themeManager.primaryColor))
                                                
                                                Text(set.title)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            HStack(alignment: .center, spacing: 8) {
                                                // Custom date display to reduce spacing between icon and text
                                                HStack(spacing: 4) {
                                                    Image(systemName: "calendar")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text("\(set.dateCreated, style: .date)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()

                                                // Compact mode badge on home list: tighter icon-text spacing, more outer padding
                                                HStack(spacing: 4) {
                                                    Image(systemName: set.studySetMode == .topic ? "lightbulb.fill" : "doc.text.fill")
                                                        .font(.caption2)
                                                    Text(set.studySetMode == .topic ? "Learning Topic" : "From Content")
                                                        .font(.caption2)
                                                }
                                                .foregroundColor(set.studySetMode == .topic ? .orange : .blue)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background((set.studySetMode == .topic ? Color.orange : Color.blue).opacity(0.14))
                                                .cornerRadius(8)
                                            }
                                        }
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .contextMenu {
                                        if !studyFolders.isEmpty {
                                            Menu("Move to Folder", systemImage: "folder") {
                                                ForEach(studyFolders) { folder in
                                                    Button {
                                                        withAnimation {
                                                            set.folder = folder
                                                        }
                                                    } label: {
                                                        Label(folder.name, systemImage: "folder")
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Button {
                                            setToRename = set
                                            renameTitle = set.title
                                            renameIconId = set.iconId
                                            isShowingRenameSheet = true
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            withAnimation {
                                                modelContext.delete(set)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            HapticsManager.shared.playTap()
                                            // Prepare rename sheet
                                            setToRename = set
                                            renameTitle = set.title
                                            renameIconId = set.iconId
                                            isShowingRenameSheet = true
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                        
                                        if !studyFolders.isEmpty {
                                            Button {
                                                HapticsManager.shared.playTap()
                                                setMovingToFolder = set
                                                isShowingMoveToFolderSheet = true
                                            } label: {
                                                Label("Folder", systemImage: "folder")
                                            }
                                            .tint(.orange)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            HapticsManager.shared.playTap()
                                            withAnimation {
                                                modelContext.delete(set)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    // Make custom row tappable and readable by VoiceOver
                                    .accessibilityElement(children: .combine)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("Study set: \(set.title). Created on \(set.dateCreated, style: .date). Mode: \(set.studySetMode == .topic ? "Learning Topic" : "From Content")")
                                    .accessibilityHint("Opens study set details")
                                }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .listSectionSpacing(0)
                    .transaction { t in t.animation = nil }
                    .animation(nil, value: searchText)
                }
            }
            .searchable(text: $searchText, isPresented: $isSearching, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search study sets")
            .animation(.linear(duration: 0.04), value: isSearching)
            .navigationTitle("StudySnap")
            .navigationDestination(for: StudySet.self) { set in
                StudySetDetailView(studySet: set)
                    .toolbar(.hidden, for: .tabBar)
            }
            .navigationDestination(for: StudyFolder.self) { folder in
                FolderDetailView(folder: folder)
                    .toolbar(.hidden, for: .tabBar)
            }
            .sheet(isPresented: $isShowingCreateFolderSheet) {
                CreateFolderView(folderToEdit: folderToEdit)
            }
            .sheet(isPresented: $isShowingMoveToFolderSheet) {
                if let set = setMovingToFolder {
                    MoveToFolderView(studySet: set, studyFolders: studyFolders)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            HapticsManager.shared.playTap()
                            isShowingInputSheet = true
                            guideManager.advanceAfterTappedCreate()
                        } label: {
                            Label("New Study Set", systemImage: "doc.badge.plus")
                        }
                        
                        Button {
                            HapticsManager.shared.playTap()
                            folderToEdit = nil
                            isShowingCreateFolderSheet = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(themeManager.primaryColor)
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .guideTarget(.homeCreate)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .fullScreenCover(isPresented: $isShowingDailyMix) {
                DailyMixView()
            }
            .sheet(isPresented: $isShowingInputSheet) {
                InputView()
                    .environmentObject(guideManager)
            }
            .sheet(isPresented: Binding(get: { setToRename != nil }, set: { if !$0 { setToRename = nil } })) {
                if let set = setToRename {
                    NavigationStack {
                        ZStack {
                            Color(uiColor: .systemGroupedBackground)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 24) {
                                // Header with icon
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(themeManager.primaryGradient)
                                            .frame(width: 80, height: 80)
                                        
                                        Image(systemName: "pencil")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Edit Study Set")
                                        .font(.title2.bold())
                                        .foregroundColor(.primary)
                                }
                                
                                // Input field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Title")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Enter new title", text: $renameTitle)
                                        .font(.body)
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                                }
                                .padding(.horizontal)
                                
                                // Icon Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Icon")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                        ForEach(StudySetIcon.allIcons) { icon in
                                            Button(action: {
                                                HapticsManager.shared.playTap()
                                                renameIconId = icon.id
                                            }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(renameIconId == icon.id ? themeManager.primaryColor : Color(uiColor: .tertiarySystemGroupedBackground))
                                                        .frame(width: 48, height: 48)
                                                    
                                                    Image(systemName: icon.systemName)
                                                        .font(.system(size: 20))
                                                        .foregroundColor(renameIconId == icon.id ? .white : .primary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                Spacer()
                            }
                            .padding(.top, 40)
                            .padding(.horizontal)
                        }
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    HapticsManager.shared.playTap()
                                    setToRename = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button {
                                    HapticsManager.shared.playTap()
                                    withAnimation {
                                        set.title = renameTitle
                                        set.iconId = renameIconId
                                    }
                                    setToRename = nil
                                } label: {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .foregroundColor(themeManager.primaryColor)
                                }
                            }
                        }
                    }
                } else {
                    EmptyView()
                }
            }
            .overlayPreferenceValue(GuideTargetPreferenceKey.self) { prefs in
                GeometryReader { proxy in
                    GuideOverlayLayer(
                        guideManager: guideManager,
                        accent: themeManager.primaryColor,
                        prefs: prefs,
                        geometry: proxy,
                        selectedTab: selectedTab,
                        onSkip: { guideManager.skipGuide() },
                        onAdvance: nil
                    )
                    .zIndex(200)  // Ensure guide overlay appears above all other content
                }
                .allowsHitTesting(!guideManager.isCollapsed)  // Allow interaction only when expanded
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if guideManager.currentStep == .configureModel && newValue == .settings {
                    guideManager.advanceAfterConfiguredModel()
                }
                if guideManager.currentStep == .exploreGamification {
                    guideManager.finishGamification()
                }
            }
        }
    }
    
    // MARK: - Daily Mix Card
    
    private var hasDailyMixContent: Bool {
        let totalQuestions = studySets.reduce(0) { $0 + $1.questions.count }
        let totalFlashcards = studySets.reduce(0) { $0 + $1.flashcards.count }
        return totalQuestions > 15 && totalFlashcards > 15
    }
    
    private var dailyMixCard: some View {
        Group {
            if hasDailyMixContent {
                Button {
                    HapticsManager.shared.playTap()
                    isShowingDailyMix = true
                } label: {
                    HStack(spacing: 14) {
                        // Icon with solid background
                        ZStack {
                            Circle()
                                .fill(themeManager.primaryColor)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "bolt.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Daily Mix")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if gamificationManager.hasDailyMixCompletedToday(profile: profile) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                        Text("Done")
                                            .font(.caption2.bold())
                                    }
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(6)
                                }
                            }
                            
                            Text(gamificationManager.hasDailyMixCompletedToday(profile: profile)
                                 ? "Great job! Come back tomorrow."
                                 : "Keep your streak alive!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1.5)
                            )
                    )
                    .shadow(color: themeManager.primaryColor.opacity(0.12), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Gamification Header
    
    private var gamificationHeader: some View {
        HStack(spacing: 16) {
            // Level & XP
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Level \(profile.level)")
                        .font(.subheadline.bold())
                }
                
                // XP Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.horizontalGradient)
                            .frame(width: geometry.size.width * profile.xpProgress, height: 6)
                    }
                }
                .frame(height: 6)
                
                Text("\(profile.xpToNextLevel) XP to next")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 40)
            
            // Streak
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundColor(profile.currentStreak > 0 ? .orange : .gray)
                    Text("\(profile.currentStreak)")
                        .font(.title3.bold())
                }
                Text("Streak")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            // Coins
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                    Text("\(profile.coins)")
                        .font(.title3.bold())
                }
                Text("Coins")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(studySets[index])
            }
        }
    }

}

// MARK: - Folder Card

private struct FolderCard: View {
    let folder: StudyFolder
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let iconSize = width * 0.36
            let spacing = width * 0.08

            VStack(spacing: spacing) {
                // Icon
                Circle()
                    .fill(themeManager.secondaryColor.opacity(0.9))
                    .overlay(
                        Circle()
                            .stroke(themeManager.primaryColor.opacity(0.25), lineWidth: 2)
                    )
                    .frame(width: iconSize, height: iconSize)
                    .overlay(
                        Image(systemName: StudySetIcon.icon(for: folder.iconId)?.systemName ?? "folder.fill")
                            .font(.system(size: iconSize * 0.45, weight: .semibold))
                            .foregroundColor(.white)
                    )

                // Title and count
                VStack(spacing: spacing * 0.7) {
                    Text(folder.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.caption2)
                        Text("\(folder.studySets.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(themeManager.primaryColor)
                    )
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(themeManager.primaryColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(themeManager.primaryColor.opacity(0.2), lineWidth: 1.1)
                    )
            )
            .shadow(color: themeManager.primaryColor.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .aspectRatio(1.1, contentMode: .fit)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [StudySet.self, UserProfile.self], inMemory: true)
}

