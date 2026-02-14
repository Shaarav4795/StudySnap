import SwiftUI
import SwiftData
import Shimmer
import SwiftUIIntrospect
import ConfettiSwiftUI

struct QuestionsView: View {
    @Environment(\.modelContext) private var modelContext
    let studySet: StudySet
    @State private var questions: [Question]
    @State private var isShowingQuiz = false
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var guideManager: GuideManager
    @State private var showGenerateMoreSheet = false
    @State private var isGeneratingMore = false
    @State private var additionalQuestionCount: Double = 5
    @State private var relativeDifficulty: AIService.RelativeDifficulty = .same
    @State private var generationError: String?
    @State private var quizConfettiCounter = 0
    
    init(studySet: StudySet) {
        self.studySet = studySet
        _questions = State(initialValue: studySet.questions)
    }
    
    var body: some View {
        let isOverlayPresented = showGenerateMoreSheet
        ZStack {
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
                    .buttonStyle(PressScaleButtonStyle())
                    .guideTarget(.questionsStartQuiz)
                }

                Section {
                    Button(action: {
                        HapticsManager.shared.playTap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showGenerateMoreSheet = true
                        }
                    }) {
                        Label("Generate More", systemImage: "plus.circle")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(themeManager.primaryColor.opacity(0.1))
                    .buttonStyle(PressScaleButtonStyle())
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
            .listSectionSpacing(8)
            .introspect(.scrollView, on: .iOS(.v17, .v18)) { scrollView in
                scrollView.keyboardDismissMode = .interactive
                scrollView.delaysContentTouches = false
            }
            .navigationTitle("Study Questions")
            .blur(radius: isOverlayPresented ? 1 : 0)
            .allowsHitTesting(!isOverlayPresented)
            
            if showGenerateMoreSheet {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showGenerateMoreSheet = false
                        }
                    }
                
                GenerateMorePopup(
                    title: "Generate More Questions",
                    count: $additionalQuestionCount,
                    countRange: 3...20,
                    countLabel: "Questions",
                    difficulty: $relativeDifficulty,
                    isGenerating: isGeneratingMore,
                    themeColor: themeManager.primaryColor,
                    onGenerate: { generateMoreQuestions() },
                    onDismiss: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showGenerateMoreSheet = false
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isShowingQuiz) {
            NavigationStack {
                QuizView(studySet: studySet)
            }
        }
        .alert("Could not generate", isPresented: Binding(
            get: { generationError != nil },
            set: { if !$0 { generationError = nil } }
        )) {
            Button("OK", role: .cancel) {
                HapticsManager.shared.playTap()
                generationError = nil
            }
        } message: {
            if let generationError {
                Text(generationError)
            }
        }
        .onChange(of: isShowingQuiz) { _, newValue in
            // When the quiz sheet closes, advance the guide step and refresh questions.
            if newValue == false, guideManager.currentStep == .exploreQuiz {
                guideManager.advanceAfterVisitedQuiz()
            }
            if newValue == false {
                questions = studySet.questions
                quizConfettiCounter += 1
            }
        }
        .confettiCannon(counter: $quizConfettiCounter)
    }

    private func generateMoreQuestions() {
        HapticsManager.shared.playTap()
        generationError = nil
        isGeneratingMore = true
        Task {
            let service = AIService.shared
            do {
                let newData = try await service.generateQuestions(
                    from: studySet.originalText,
                    count: Int(additionalQuestionCount),
                    relativeDifficulty: relativeDifficulty
                )
                await MainActor.run {
                    let newQuestions = newData.map { data -> Question in
                        let question = Question(
                            prompt: data.question,
                            answer: data.answer,
                            options: data.options,
                            explanation: data.explanation
                        )
                        question.studySet = studySet
                        modelContext.insert(question)
                        return question
                    }
                    questions.append(contentsOf: newQuestions)
                    isGeneratingMore = false
                    showGenerateMoreSheet = false
                }
            } catch {
                await MainActor.run {
                    generationError = AIService.formatError(error)
                    isGeneratingMore = false
                }
            }
        }
    }
}

// MARK: - Generate-more sheet

private struct GenerateMorePopup: View {
    let title: String
    @Binding var count: Double
    let countRange: ClosedRange<Double>
    let countLabel: String
    @Binding var difficulty: AIService.RelativeDifficulty
    let isGenerating: Bool
    let themeColor: Color
    let onGenerate: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(countLabel)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(count))")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                }
                Slider(value: $count, in: countRange, step: 1)
                    .tint(themeColor)
                    .onChange(of: count) { _, _ in
                        HapticsManager.shared.playTap()
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.subheadline)
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(AIService.RelativeDifficulty.allCases) { diff in
                        Text(diff.rawValue).tag(diff)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: difficulty) { _, _ in
                    HapticsManager.shared.playTap()
                }
            }
            
            Button(action: onGenerate) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(isGenerating ? "Generating..." : "Generate")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shimmering(active: isGenerating)
            }
            .buttonStyle(.plain)
            .buttonStyle(PressScaleButtonStyle())
            .disabled(isGenerating)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 6)
    }
}
