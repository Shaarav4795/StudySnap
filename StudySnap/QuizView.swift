import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var gamificationManager = GamificationManager.shared
    
    let questions: [Question]
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    @State private var isAnswerVisible = false
    @State private var isQuizFinished = false
    @State private var hasRecordedCompletion = false
    @Environment(\.dismiss) var dismiss
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        return gamificationManager.getOrCreateProfile(context: modelContext)
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                if isQuizFinished {
                    VStack(spacing: 30) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.yellow)
                            .padding()
                        
                        Text("Quiz Complete!")
                            .font(.largeTitle)
                            .bold()
                        
                        VStack(spacing: 10) {
                            Text("Your Score")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("\(score) / \(questions.count)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                        
                        // XP and Coins Rewards Display
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.blue)
                                    Text("+\(calculateXPEarned())")
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
                                    Text("+\(calculateCoinsEarned())")
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
                        
                        // Perfect Score Bonus
                        if score == questions.count && questions.count > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.orange)
                                Text("Perfect Score Bonus!")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(20)
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                } else if !questions.isEmpty {
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            Text("Question \(currentQuestionIndex + 1)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(questions.count - currentQuestionIndex - 1) remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        ProgressView(value: Double(currentQuestionIndex), total: Double(questions.count))
                            .tint(.accentColor)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 20) {
                                // Question Card
                                VStack {
                                    MathTextView(questions[currentQuestionIndex].prompt, fontSize: 20)
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
                                .padding()
                                
                                // Options
                                if let options = questions[currentQuestionIndex].options, !options.isEmpty {
                                    VStack(spacing: 16) {
                                        ForEach(Array(options.enumerated()), id: \.element) { index, option in
                                            Button(action: { checkAnswer(option) }) {
                                                HStack(spacing: 15) {
                                                    // Option Letter Circle
                                                    ZStack {
                                                        Circle()
                                                            .fill(isAnswerVisible ? (option == questions[currentQuestionIndex].answer ? Color.green : (option == selectedAnswer ? Color.red : Color.gray.opacity(0.2))) : Color.accentColor.opacity(0.1))
                                                            .frame(width: 36, height: 36)
                                                        
                                                        Text(["A", "B", "C", "D"][index % 4])
                                                            .font(.headline)
                                                            .foregroundColor(isAnswerVisible ? (option == questions[currentQuestionIndex].answer || option == selectedAnswer ? .white : .secondary) : .accentColor)
                                                    }
                                                    
                                                    MathTextView(option, fontSize: 17)
                                                        .fontWeight(.medium)
                                                        .multilineTextAlignment(.leading)
                                                        .foregroundColor(.primary)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                    
                                                    Spacer()
                                                    
                                                    if isAnswerVisible {
                                                        if option == questions[currentQuestionIndex].answer {
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
                                                        .fill(backgroundColor(for: option))
                                                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(borderColor(for: option), lineWidth: isAnswerVisible && (option == questions[currentQuestionIndex].answer || option == selectedAnswer) ? 2 : 0)
                                                )
                                            }
                                            .disabled(isAnswerVisible)
                                            .scaleEffect(selectedAnswer == option ? 0.98 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedAnswer)
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    if isAnswerVisible {
                                        if let explanation = questions[currentQuestionIndex].explanation, !explanation.isEmpty {
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
                                } else {
                                    // Fallback for questions without options (legacy support)
                                    if isAnswerVisible {
                                        VStack(spacing: 16) {
                                            Text(questions[currentQuestionIndex].answer)
                                                .font(.title3)
                                                .foregroundColor(.primary)
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                                .cornerRadius(12)
                                                .transition(.opacity)
                                        }
                                        .padding()
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        
                        // Fixed Footer
                        VStack {
                            if let options = questions[currentQuestionIndex].options, !options.isEmpty {
                                if isAnswerVisible {
                                    Button("Next Question") {
                                        nextQuestion()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .frame(maxWidth: .infinity)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            } else {
                                if isAnswerVisible {
                                    HStack(spacing: 20) {
                                        Button(action: { submitAnswer(correct: false) }) {
                                            Label("Incorrect", systemImage: "xmark.circle")
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(10)
                                        
                                        Button(action: { submitAnswer(correct: true) }) {
                                            Label("Correct", systemImage: "checkmark.circle")
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.green)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                    .padding(.horizontal)
                                } else {
                                    Button("Show Answer") {
                                        withAnimation {
                                            isAnswerVisible = true
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemGroupedBackground))
                    }
                } else {
                    VStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No questions available for quiz.")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Quiz Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @State private var selectedAnswer: String?
    
    private func checkAnswer(_ option: String) {
        selectedAnswer = option
        isAnswerVisible = true
        if option == questions[currentQuestionIndex].answer {
            score += 1
        }
    }
    
    private func borderColor(for option: String) -> Color {
        guard isAnswerVisible else { return .gray.opacity(0.3) }
        if option == questions[currentQuestionIndex].answer {
            return .green
        }
        if option == selectedAnswer {
            return .red
        }
        return .gray.opacity(0.3)
    }
    
    private func backgroundColor(for option: String) -> Color {
        guard isAnswerVisible else { return Color(uiColor: .secondarySystemGroupedBackground) }
        if option == questions[currentQuestionIndex].answer {
            return .green.opacity(0.1)
        }
        if option == selectedAnswer {
            return .red.opacity(0.1)
        }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < questions.count - 1 {
            currentQuestionIndex += 1
            isAnswerVisible = false
            selectedAnswer = nil
        } else {
            isQuizFinished = true
            recordQuizCompletion()
        }
    }
    
    private func submitAnswer(correct: Bool) {
        if correct {
            score += 1
        }
        nextQuestion()
    }
    
    private func recordQuizCompletion() {
        guard !hasRecordedCompletion else { return }
        hasRecordedCompletion = true
        
        gamificationManager.recordQuizCompletion(
            score: score,
            totalQuestions: questions.count,
            profile: profile,
            context: modelContext
        )
    }
    
    private func calculateXPEarned() -> Int {
        var xp = XPRewards.quizCompleted
        xp += score * XPRewards.questionCorrect
        if score == questions.count && questions.count > 0 {
            xp += XPRewards.perfectQuiz
        }
        let multiplier = XPRewards.streakMultiplier(for: profile.currentStreak)
        return Int(Double(xp) * multiplier)
    }
    
    private func calculateCoinsEarned() -> Int {
        var coins = CoinRewards.quizCompleted
        if score == questions.count && questions.count > 0 {
            coins += CoinRewards.perfectQuiz
        }
        return coins
    }
}
