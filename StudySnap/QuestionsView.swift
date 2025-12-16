import SwiftUI

struct QuestionsView: View {
    let questions: [Question]
    @State private var isShowingQuiz = false
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var guideManager: GuideManager
    
    var body: some View {
        List {
            Section {
                Button(action: {
                    HapticsManager.shared.playTap()
                    isShowingQuiz = true
                }) {
                    Label("Start Quiz", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(themeManager.primaryColor.opacity(0.1))
                .guideTarget(.questionsStartQuiz)
            }
            
            ForEach(questions) { question in
                DisclosureGroup(
                    content: {
                        MathTextView(question.answer, fontSize: 15)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    },
                    label: {
                        MathTextView(question.prompt, fontSize: 17)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Question: \(question.prompt)")
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Study Questions")
        .sheet(isPresented: $isShowingQuiz) {
            NavigationStack {
                QuizView(questions: questions)
            }
        }
        .onChange(of: isShowingQuiz) { _, newValue in
            // Advance when quiz sheet closes to avoid double overlays
            if newValue == false, guideManager.currentStep == .exploreQuiz {
                guideManager.advanceAfterVisitedQuiz()
            }
        }
    }
}
