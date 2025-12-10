import SwiftUI

struct StudySetDetailView: View {
    let studySet: StudySet
    @EnvironmentObject private var guideManager: GuideManager
    @State private var selectedTab: Int = 0
    
    private var isTopicMode: Bool {
        studySet.studySetMode == .topic
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                SummaryView(summary: studySet.summary ?? "No summary available.", isGuide: isTopicMode)
                    .tabItem {
                        Label(isTopicMode ? "Guide" : "Summary", systemImage: isTopicMode ? "book.fill" : "text.alignleft")
                    }
                    .tag(0)
                
                QuestionsView(questions: studySet.questions)
                    .tabItem {
                        Label("Questions", systemImage: "list.bullet.clipboard")
                    }
                    .tag(1)
                
                FlashcardsView(flashcards: studySet.flashcards)
                    .tabItem {
                        Label("Flashcards", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .tag(2)
            }
            .onAppear {
                if guideManager.currentStep == .openSet {
                    guideManager.advanceAfterOpenedSet()
                }
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
}
