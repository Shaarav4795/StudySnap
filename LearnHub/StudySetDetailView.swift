import SwiftUI

struct StudySetDetailView: View {
    let studySet: StudySet
    @EnvironmentObject private var guideManager: GuideManager
    @State private var selectedTab: Int = 0
    @State private var loadedTabs: Set<Int> = [0]
    
    private var isTopicMode: Bool {
        studySet.studySetMode == .topic
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                lazyTab(tag: 0) {
                    SummaryView(summary: studySet.summary ?? "No summary available.", isGuide: isTopicMode)
                }
                    .tabItem {
                        Label(isTopicMode ? "Guide" : "Summary", systemImage: isTopicMode ? "book.fill" : "text.alignleft")
                    }
                    .tag(0)
                
                lazyTab(tag: 1) {
                    QuestionsView(studySet: studySet)
                }
                    .tabItem {
                        Label("Questions", systemImage: "list.bullet.clipboard")
                    }
                    .tag(1)
                
                lazyTab(tag: 2) {
                    FlashcardsView(studySet: studySet)
                }
                    .tabItem {
                        Label("Flashcards", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .tag(2)
                
                lazyTab(tag: 3) {
                    StudyChatView(studySet: studySet)
                }
                    .tabItem {
                        Label("Tutor", systemImage: "brain.head.profile")
                    }
                    .tag(3)
            }
            .onAppear {
                if guideManager.currentStep == .openSet {
                    guideManager.advanceAfterOpenedSet()
                }
                loadedTabs.insert(0)
            }
            .onChange(of: selectedTab) { _, _ in
                loadedTabs.insert(selectedTab)
                HapticsManager.shared.lightImpact()
            }
        }
        .navigationTitle(studySet.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlayPreferenceValue(GuideTargetPreferenceKey.self) { prefs in
            GeometryReader { proxy in
                GuideOverlayLayer(
                    guideManager: guideManager,
                    accent: .accentColor,
                    prefs: prefs,
                    geometry: proxy,
                    onSkip: { guideManager.skipGuide() },
                    onAdvance: nil
                )
            }
        }
    }

    @ViewBuilder
    private func lazyTab<Content: View>(tag: Int, @ViewBuilder content: () -> Content) -> some View {
        if loadedTabs.contains(tag) || selectedTab == tag {
            content()
        } else {
            Color.clear
        }
    }
}
