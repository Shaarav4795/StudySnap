//
//  ContentView.swift
//  StudySnap
//
//  Created by Shaarav on 30/11/2025.
//

import SwiftUI
import SwiftData

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
    
    enum AppDestination: Hashable {
        case profile
        case settings
    }
    
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
        homeView
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
                navigationPath.append(set)
            }
        } else if url.host == "stats" {
            // Navigate to profile for stats
            navigationPath.append(AppDestination.profile)
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
                        // Gamification Header as first item in list
                        Section {
                            gamificationHeader
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                        .listRowSeparator(.hidden)
                        
                        // Folders Section
                        if !filteredFolders.isEmpty {
                            Section(header: Text("Folders")) {
                                ForEach(filteredFolders) { folder in
                                    ZStack {
                                        NavigationLink(value: folder) {
                                            EmptyView()
                                        }
                                        .opacity(0)
                                        
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: StudySetIcon.icon(for: folder.iconId)?.systemName ?? "folder.fill")
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(Circle().fill(themeManager.primaryColor))
                                                
                                                Text(folder.name)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            HStack(alignment: .center, spacing: 8) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "calendar")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text("\(folder.dateCreated, style: .date)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()

                                                HStack(spacing: 4) {
                                                    Image(systemName: "doc.on.doc.fill")
                                                        .font(.caption2)
                                                    Text("\(folder.studySets.count) Sets")
                                                        .font(.caption2)
                                                }
                                                .foregroundColor(.purple)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.purple.opacity(0.14))
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
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button {
                                            HapticsManager.shared.playTap()
                                            folderToEdit = folder
                                            isShowingCreateFolderSheet = true
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            HapticsManager.shared.playTap()
                                            withAnimation {
                                                modelContext.delete(folder)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        if !filteredStudySets.isEmpty {
                            Section(header: !filteredFolders.isEmpty ? Text("Study Sets") : nil) {
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
            }
            .navigationDestination(for: StudyFolder.self) { folder in
                FolderDetailView(folder: folder)
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView()
                        .environmentObject(guideManager)
                case .settings:
                    ModelSettingsView()
                        .onDisappear {
                            guideManager.advanceAfterConfiguredModel()
                        }
                }
            }
            .sheet(isPresented: $isShowingCreateFolderSheet) {
                CreateFolderView(folderToEdit: folderToEdit)
            }
            .sheet(isPresented: $isShowingMoveToFolderSheet) {
                if let set = setMovingToFolder {
                    MoveToFolderView(studySet: set)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(value: AppDestination.profile) {
                        profileButton
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        NavigationLink(value: AppDestination.settings) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.primaryColor)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "gear")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .accessibilityLabel("Model Settings")
                        .guideTarget(.homeSettings)

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
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .guideTarget(.homeCreate)
                    }
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
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
                                Button("Cancel") {
                                    HapticsManager.shared.playTap()
                                    setToRename = nil
                                }
                                .foregroundColor(.secondary)
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    HapticsManager.shared.playTap()
                                    withAnimation {
                                        set.title = renameTitle
                                        set.iconId = renameIconId
                                    }
                                    setToRename = nil
                                }
                                .foregroundColor(themeManager.primaryColor)
                                .bold()
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
                        onSkip: { guideManager.skipGuide() },
                        onAdvance: nil
                    )
                    .zIndex(200)  // Ensure guide overlay appears above all other content
                }
                .allowsHitTesting(!guideManager.isCollapsed)  // Allow interaction only when expanded
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
    
    // MARK: - Profile Button
    
    private var profileButton: some View {
        HStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(themeManager.primaryGradient)
                    .frame(width: 32, height: 32)
                
                if let avatar = AvatarItem.avatar(for: profile.selectedAvatarId) {
                    Image(avatar.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(studySets[index])
            }
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [StudySet.self, UserProfile.self], inMemory: true)
}

