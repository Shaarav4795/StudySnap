//
//  DailyMixView.swift
//  StudySnap
//
//  Created by Shaarav on 28/12/2025.
//

import SwiftUI
import SwiftData

// MARK: - Seeded Random Number Generator

/// A deterministic random number generator that produces the same sequence for a given seed
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // Simple xorshift algorithm for deterministic randomness
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

struct DailyMixView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StudySet.dateCreated, order: .reverse) private var studySets: [StudySet]
    @Query private var profiles: [UserProfile]
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    // Session state
    @State private var phase: DailyMixPhase = .intro
    @State private var mixQuestions: [Question] = []
    @State private var mixFlashcards: [Flashcard] = []
    
    // Quiz state (reusing QuizView patterns)
    @State private var currentQuestionIndex = 0
    @State private var questionsCorrect = 0
    @State private var isAnswerVisible = false
    @State private var selectedAnswer: String?
    
    // Flashcard state (reusing FlashcardsView patterns)
    @State private var currentFlashcardIndex = 0
    @State private var flashcardsStudied = 0
    @State private var flashcardsMastered = 0
    @State private var studiedCardIds: Set<UUID> = []
    @State private var masteredCardIds: Set<UUID> = []
    
    @State private var hasRecordedCompletion = false
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        return gamificationManager.getOrCreateProfile(context: modelContext)
    }
    
    private var isAlreadyCompleted: Bool {
        gamificationManager.hasDailyMixCompletedToday(profile: profile)
    }
    
    enum DailyMixPhase {
        case intro
        case questions
        case flashcards
        case complete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                switch phase {
                case .intro:
                    introView
                case .questions:
                    questionsPhaseView
                case .flashcards:
                    flashcardsPhaseView
                case .complete:
                    completionView
                }
            }
            .navigationTitle("Daily Mix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .onAppear {
            generateDailyMix()
        }
    }
    
    // MARK: - Intro View
    
    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Motivational Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeManager.primaryGradient)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                
                Text(isAlreadyCompleted ? "You've Crushed Today!" : "Ready for Today's Challenge?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(isAlreadyCompleted
                     ? "Amazing work! Come back tomorrow for a fresh mix."
                     : "Complete 5 questions and 5 flashcards to keep your streak alive!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }
            
            // Stats Preview
            if !isAlreadyCompleted {
                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        Text("5 Questions")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                    
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "rectangle.stack.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                        Text("5 Flashcards")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            
            // Rewards Preview
            if !isAlreadyCompleted {
                VStack(spacing: 12) {
                    Text("Potential Rewards")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.blue)
                            Text("Up to \(calculateMaxXP()) XP")
                                .font(.subheadline.bold())
                                .foregroundColor(.blue)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.orange)
                            Text("Up to \(calculateMaxCoins()) Coins")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.primaryColor.opacity(0.1))
                )
            }
            
            // Streak Reminder
            if profile.currentStreak > 0 && !isAlreadyCompleted {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(profile.currentStreak) day streak — don't break it!")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(20)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                if !isAlreadyCompleted && !mixQuestions.isEmpty && !mixFlashcards.isEmpty {
                    Button(action: {
                        HapticsManager.shared.playTap()
                        withAnimation {
                            phase = .questions
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Daily Mix")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.primaryColor)
                        .cornerRadius(16)
                    }
                } else if isAlreadyCompleted {
                    Button(action: {
                        HapticsManager.shared.playTap()
                        // Allow practice run without XP/coins
                        withAnimation {
                            phase = .questions
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Practice Again (No Rewards)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.primaryColor)
                        .cornerRadius(16)
                    }
                } else {
                    // Not enough content
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text("Create more study sets to unlock Daily Mix!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .padding()
    }
    
    // MARK: - Questions Phase View
    
    private var questionsPhaseView: some View {
        VStack(spacing: 0) {
            if currentQuestionIndex < mixQuestions.count {
                let question = mixQuestions[currentQuestionIndex]
                
                VStack(spacing: 20) {
                    // Progress Header
                    HStack {
                        Text("Question \(currentQuestionIndex + 1) of \(mixQuestions.count)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(questionsCorrect) correct")
                                .font(.subheadline.bold())
                        }
                    }
                    .padding(.horizontal)
                    
                    ProgressView(value: Double(currentQuestionIndex), total: Double(mixQuestions.count))
                        .tint(themeManager.primaryColor)
                        .padding(.horizontal)
                    
                    GeometryReader { proxy in
                        ScrollView {
                            VStack(spacing: 20) {
                            // Question Card
                            VStack {
                                MathTextView(question.prompt, fontSize: 20)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                            
                            // Options
                            if let allOptions = question.options, !allOptions.isEmpty {
                                let options = allOptions.filter { option in
                                    !((option.hasPrefix("Option ") || option.hasPrefix("option ")) && option.count < 10 && option.last?.isNumber == true)
                                }
                                
                                VStack(spacing: 16) {
                                    ForEach(Array(options.enumerated()), id: \.element) { index, option in
                                        Button(action: {
                                            HapticsManager.shared.playTap()
                                            checkAnswer(option, correctAnswer: question.answer)
                                        }) {
                                            HStack(spacing: 15) {
                                                ZStack {
                                                    Circle()
                                                        .fill(optionCircleColor(for: option, correctAnswer: question.answer))
                                                        .frame(width: 36, height: 36)
                                                    
                                                    Text(["A", "B", "C", "D"][index % 4])
                                                        .font(.headline)
                                                        .foregroundColor(optionLetterColor(for: option, correctAnswer: question.answer))
                                                }
                                                
                                                MathTextView(option, fontSize: 17)
                                                    .fontWeight(.medium)
                                                    .multilineTextAlignment(.leading)
                                                    .foregroundColor(.primary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                
                                                Spacer()
                                                
                                                if isAnswerVisible {
                                                    if option == question.answer {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.green)
                                                            .font(.title2)
                                                    } else if option == selectedAnswer {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                            .font(.title2)
                                                    }
                                                }
                                            }
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(optionBackgroundColor(for: option, correctAnswer: question.answer))
                                                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(optionBorderColor(for: option, correctAnswer: question.answer), lineWidth: isAnswerVisible && (option == question.answer || option == selectedAnswer) ? 2 : 0)
                                            )
                                        }
                                        .disabled(isAnswerVisible)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Explanation
                                if isAnswerVisible, let explanation = question.explanation, !explanation.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Explanation")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        
                                        MathTextView(explanation, fontSize: 16)
                                            .foregroundColor(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                    .transition(.opacity)
                                }
                            }
                        }
                        .padding(.bottom, 100)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height, alignment: isAnswerVisible ? .top : .center)
                    }
                    }
                }
                
                // Fixed Footer
                if isAnswerVisible {
                    VStack {
                        Button(action: {
                            HapticsManager.shared.playTap()
                            nextQuestion()
                        }) {
                            Text(currentQuestionIndex < mixQuestions.count - 1 ? "Next Question" : "Continue to Flashcards")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.primaryColor)
                                .cornerRadius(16)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
        }
    }
    
    // MARK: - Flashcards Phase View
    
    private var flashcardsPhaseView: some View {
        VStack(spacing: 0) {
            if currentFlashcardIndex < mixFlashcards.count {
                // Progress Stats Bar
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(flashcardsStudied) Studied")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("\(flashcardsMastered) Mastered")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Flashcard TabView
                TabView(selection: $currentFlashcardIndex) {
                    ForEach(mixFlashcards.indices, id: \.self) { index in
                        DailyMixFlashcardView(
                            card: mixFlashcards[index],
                            isStudied: studiedCardIds.contains(mixFlashcards[index].id),
                            isMastered: masteredCardIds.contains(mixFlashcards[index].id),
                            onStudied: { markStudied(mixFlashcards[index].id) },
                            onMastered: { markMastered(mixFlashcards[index].id) },
                            themeColor: themeManager.primaryColor
                        )
                        .tag(index)
                        .padding()
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Bottom Bar
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack")
                            .font(.caption)
                        Text("\(currentFlashcardIndex + 1) of \(mixFlashcards.count)")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if flashcardsStudied > 0 {
                        Button(action: {
                            HapticsManager.shared.playTap()
                            finishDailyMix()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Finish Daily Mix")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(themeManager.primaryColor)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Celebration
            ZStack {
                Circle()
                    .fill(themeManager.primaryGradient)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text("Daily Mix Complete!")
                .font(.largeTitle.bold())
            
            Text(motivationalMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Results Summary
            VStack(spacing: 16) {
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("\(questionsCorrect)/\(mixQuestions.count)")
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                        Text("Questions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(flashcardsStudied)/\(mixFlashcards.count)")
                            .font(.title2.bold())
                            .foregroundColor(.orange)
                        Text("Flashcards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(flashcardsMastered)")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                        Text("Mastered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            
            // Rewards (only if not already completed today)
            if !isAlreadyCompleted {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.blue)
                            Text("+\(calculateEarnedXP())")
                                .font(.headline.bold())
                                .foregroundColor(.blue)
                        }
                        Text("XP Earned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.yellow)
                            Text("+\(calculateEarnedCoins())")
                                .font(.headline.bold())
                                .foregroundColor(.yellow)
                        }
                        Text("Coins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Streak Update
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Streak maintained!")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(20)
            } else {
                Text("Practice complete — no rewards for repeats!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                HapticsManager.shared.playTap()
                dismiss()
            }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.primaryColor)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func generateDailyMix() {
        // Collect all questions and flashcards from all study sets
        var allQuestions: [Question] = []
        var allFlashcards: [Flashcard] = []
        
        for set in studySets {
            allQuestions.append(contentsOf: set.questions)
            allFlashcards.append(contentsOf: set.flashcards)
        }
        
        // Use date-based seed for consistent daily selection
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let seed = UInt64(today.timeIntervalSince1970)
        var generator = SeededRandomNumberGenerator(seed: seed)
        
        // Sort by ID first for consistent ordering, then shuffle with seeded generator
        let sortedQuestions = allQuestions.sorted { $0.id.uuidString < $1.id.uuidString }
        let sortedFlashcards = allFlashcards.sorted { $0.id.uuidString < $1.id.uuidString }
        
        mixQuestions = Array(sortedQuestions.shuffled(using: &generator).prefix(5))
        mixFlashcards = Array(sortedFlashcards.shuffled(using: &generator).prefix(5))
    }
    
    private func checkAnswer(_ option: String, correctAnswer: String) {
        selectedAnswer = option
        isAnswerVisible = true
        if option == correctAnswer {
            questionsCorrect += 1
        }
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < mixQuestions.count - 1 {
            currentQuestionIndex += 1
            isAnswerVisible = false
            selectedAnswer = nil
        } else {
            // Move to flashcards phase
            withAnimation {
                phase = .flashcards
            }
        }
    }
    
    private func markStudied(_ cardId: UUID) {
        guard !studiedCardIds.contains(cardId) else { return }
        studiedCardIds.insert(cardId)
        flashcardsStudied += 1
    }
    
    private func markMastered(_ cardId: UUID) {
        guard !masteredCardIds.contains(cardId) else { return }
        masteredCardIds.insert(cardId)
        flashcardsMastered += 1
        if !studiedCardIds.contains(cardId) {
            studiedCardIds.insert(cardId)
            flashcardsStudied += 1
        }
    }
    
    private func finishDailyMix() {
        guard !hasRecordedCompletion else {
            withAnimation { phase = .complete }
            return
        }
        hasRecordedCompletion = true
        
        // Only award XP/coins if not already completed today
        if !isAlreadyCompleted {
            gamificationManager.recordDailyMixCompletion(
                questionsCorrect: questionsCorrect,
                flashcardsStudied: flashcardsStudied,
                profile: profile,
                context: modelContext
            )
        }
        
        withAnimation {
            phase = .complete
        }
    }
    
    // MARK: - Calculations
    
    private func calculateMaxXP() -> Int {
        let base = XPRewards.dailyMixBase
        let questions = 5 * XPRewards.dailyMixQuestionCorrect
        let flashcards = 5 * XPRewards.dailyMixFlashcard
        let multiplier = XPRewards.streakMultiplier(for: profile.currentStreak)
        return Int(Double(base + questions + flashcards) * multiplier)
    }
    
    private func calculateMaxCoins() -> Int {
        return CoinRewards.dailyMixBase + (5 * CoinRewards.dailyMixQuestionCorrect) + (5 * CoinRewards.dailyMixFlashcard)
    }
    
    private func calculateEarnedXP() -> Int {
        let base = XPRewards.dailyMixBase
        let questions = questionsCorrect * XPRewards.dailyMixQuestionCorrect
        let flashcards = flashcardsStudied * XPRewards.dailyMixFlashcard
        let multiplier = XPRewards.streakMultiplier(for: profile.currentStreak)
        return Int(Double(base + questions + flashcards) * multiplier)
    }
    
    private func calculateEarnedCoins() -> Int {
        return CoinRewards.dailyMixBase + (questionsCorrect * CoinRewards.dailyMixQuestionCorrect) + (flashcardsStudied * CoinRewards.dailyMixFlashcard)
    }
    
    private var motivationalMessage: String {
        let percentage = Double(questionsCorrect) / Double(max(1, mixQuestions.count))
        if percentage >= 1.0 {
            return "Perfect score! You're unstoppable! 🔥"
        } else if percentage >= 0.8 {
            return "Excellent work! Keep that momentum going!"
        } else if percentage >= 0.6 {
            return "Great effort! Practice makes perfect!"
        } else {
            return "Keep learning — every step counts!"
        }
    }
    
    // MARK: - Option Styling (matching QuizView)
    
    private func optionCircleColor(for option: String, correctAnswer: String) -> Color {
        guard isAnswerVisible else { return Color.accentColor.opacity(0.1) }
        if option == correctAnswer { return .green }
        if option == selectedAnswer { return .red }
        return Color.gray.opacity(0.2)
    }
    
    private func optionLetterColor(for option: String, correctAnswer: String) -> Color {
        guard isAnswerVisible else { return .accentColor }
        if option == correctAnswer || option == selectedAnswer { return .white }
        return .secondary
    }
    
    private func optionBackgroundColor(for option: String, correctAnswer: String) -> Color {
        guard isAnswerVisible else { return Color(uiColor: .secondarySystemGroupedBackground) }
        if option == correctAnswer { return .green.opacity(0.1) }
        if option == selectedAnswer { return .red.opacity(0.1) }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    private func optionBorderColor(for option: String, correctAnswer: String) -> Color {
        guard isAnswerVisible else { return .gray.opacity(0.3) }
        if option == correctAnswer { return .green }
        if option == selectedAnswer { return .red }
        return .gray.opacity(0.3)
    }
}

// MARK: - Daily Mix Flashcard View (reusing FlashcardView pattern)

private struct DailyMixFlashcardView: View {
    let card: Flashcard
    var isStudied: Bool = false
    var isMastered: Bool = false
    var onStudied: (() -> Void)?
    var onMastered: (() -> Void)?
    var themeColor: Color = ThemeManager.shared.primaryColor
    
    @State private var isFlipped = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 5)
                
                VStack {
                    if isFlipped {
                        MathTextView(card.back, fontSize: 20)
                            .multilineTextAlignment(.center)
                            .padding()
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        MathTextView(card.front, fontSize: 24, forceBold: true)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }
            .frame(height: 260)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .onTapGesture {
                HapticsManager.shared.playTap()
                withAnimation(.spring()) {
                    isFlipped.toggle()
                    if isFlipped && !isStudied {
                        onStudied?()
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isFlipped ? "Flashcard answer" : "Flashcard question")
            .accessibilityValue(isFlipped ? card.back : card.front)
            .accessibilityHint(isFlipped ? "Swipe or double-tap to go back to the question" : "Double-tap to flip and hear the answer")
            .accessibilityAddTraits(.isButton)
            
            // Mark as mastered button
            if isFlipped && !isMastered {
                Button(action: {
                    HapticsManager.shared.playTap()
                    onMastered?()
                }) {
                    Label("I Know This!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeColor)
                        .cornerRadius(20)
                }
            } else if isFlipped && isMastered {
                Label("Mastered!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.green.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    DailyMixView()
        .modelContainer(for: [StudySet.self, UserProfile.self], inMemory: true)
}
