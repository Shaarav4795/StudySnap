import SwiftUI
import SwiftData

struct TopicSuggestionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StudySet.dateCreated, order: .reverse) private var studySets: [StudySet]
    
    @State private var suggestions: [TopicSuggestion] = []
    @State private var isLoading = false
    @State private var selectedSuggestion: TopicSuggestion?
    @State private var showCreateSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                if isLoading {
                    loadingView
                } else if suggestions.isEmpty {
                    emptyStateView
                } else {
                    suggestionsGrid
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Topic Suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: generateSuggestions) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            if let suggestion = selectedSuggestion {
                CreateFromSuggestionView(suggestion: suggestion)
            }
        }
        .onAppear {
            if suggestions.isEmpty {
                generateSuggestions()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Discover New Topics")
                .font(.title2.bold())
            
            Text("AI-powered suggestions based on your study history")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Generating suggestions...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Suggestions Yet")
                .font(.headline)
            
            Text("Tap refresh to get AI-powered topic recommendations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: generateSuggestions) {
                Label("Generate Suggestions", systemImage: "wand.and.stars")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Suggestions Grid
    
    private var suggestionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
            ForEach(suggestions) { suggestion in
                TopicSuggestionCard(suggestion: suggestion) {
                    selectedSuggestion = suggestion
                    showCreateSheet = true
                }
            }
        }
    }
    
    // MARK: - Generate Suggestions
    
    private func generateSuggestions() {
        isLoading = true
        
        Task {
            do {
                // Get existing topics for context
                let existingTopics = studySets.prefix(10).map { $0.title }
                
                let newSuggestions = try await AIService.shared.generateTopicSuggestions(
                    existingTopics: existingTopics
                )
                
                await MainActor.run {
                    self.suggestions = newSuggestions
                    self.isLoading = false
                }
            } catch {
                print("Error generating suggestions: \(error)")
                await MainActor.run {
                    // Fallback suggestions
                    self.suggestions = TopicSuggestion.fallbackSuggestions
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Topic Suggestion Model

struct TopicSuggestion: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let difficulty: String
    let estimatedTime: String
    let icon: String
    
    nonisolated static var fallbackSuggestions: [TopicSuggestion] {
        [
            TopicSuggestion(
                title: "Introduction to Machine Learning",
                description: "Learn the fundamentals of ML algorithms and their applications",
                category: "Technology",
                difficulty: "Intermediate",
                estimatedTime: "2-3 hours",
                icon: "brain"
            ),
            TopicSuggestion(
                title: "World History: Ancient Civilizations",
                description: "Explore the rise and fall of great ancient empires",
                category: "History",
                difficulty: "Beginner",
                estimatedTime: "1-2 hours",
                icon: "building.columns"
            ),
            TopicSuggestion(
                title: "Creative Writing Techniques",
                description: "Master storytelling, character development, and narrative structure",
                category: "Arts",
                difficulty: "Beginner",
                estimatedTime: "1-2 hours",
                icon: "pencil.and.outline"
            ),
            TopicSuggestion(
                title: "Basic Economics Principles",
                description: "Understand supply, demand, and market dynamics",
                category: "Business",
                difficulty: "Beginner",
                estimatedTime: "2-3 hours",
                icon: "chart.line.uptrend.xyaxis"
            ),
            TopicSuggestion(
                title: "Quantum Physics Basics",
                description: "Discover the fascinating world of quantum mechanics",
                category: "Science",
                difficulty: "Advanced",
                estimatedTime: "3-4 hours",
                icon: "atom"
            )
        ]
    }
}

// MARK: - Topic Suggestion Card

struct TopicSuggestionCard: View {
    let suggestion: TopicSuggestion
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Icon
                Image(systemName: suggestion.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(suggestion.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(suggestion.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                // Difficulty
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption)
                    Text(suggestion.difficulty)
                        .font(.caption)
                }
                .foregroundColor(difficultyColor)
                
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(suggestion.estimatedTime)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onSelect) {
                    Text("Start Learning")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var difficultyColor: Color {
        switch suggestion.difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }
}

// MARK: - Create From Suggestion View

struct CreateFromSuggestionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gamificationManager = GamificationManager.shared
    @Query private var profiles: [UserProfile]
    
    let suggestion: TopicSuggestion
    
    @State private var title: String
    @State private var questionCount: Double = 5
    @State private var flashcardCount: Double = 10
    @State private var summaryWordCount: Double = 200
    @State private var difficulty: AIService.SummaryDifficulty
    @State private var isGenerating = false
    
    init(suggestion: TopicSuggestion) {
        self.suggestion = suggestion
        self._title = State(initialValue: suggestion.title)
        
        // Set difficulty based on suggestion
        let diff: AIService.SummaryDifficulty
        switch suggestion.difficulty.lowercased() {
        case "beginner": diff = .beginner
        case "advanced": diff = .advanced
        default: diff = .intermediate
        }
        self._difficulty = State(initialValue: diff)
    }
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        return gamificationManager.getOrCreateProfile(context: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: suggestion.icon)
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        
                        Text(suggestion.title)
                            .font(.headline)
                    }
                    
                    Text(suggestion.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Topic")
                }
                
                Section {
                    TextField("Title", text: $title)
                } header: {
                    Text("Study Set Title")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Questions")
                            Spacer()
                            Text("\(Int(questionCount))")
                                .foregroundColor(.secondary)
                                .bold()
                        }
                        Slider(value: $questionCount, in: 1...20, step: 1)
                            .tint(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Flashcards")
                            Spacer()
                            Text("\(Int(flashcardCount))")
                                .foregroundColor(.secondary)
                                .bold()
                        }
                        Slider(value: $flashcardCount, in: 1...30, step: 1)
                            .tint(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Guide Word Count")
                            Spacer()
                            Text("\(Int(summaryWordCount))")
                                .foregroundColor(.secondary)
                                .bold()
                        }
                        Slider(value: $summaryWordCount, in: 50...500, step: 10)
                            .tint(.accentColor)
                    }
                    
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(AIService.SummaryDifficulty.allCases) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                } header: {
                    Text("Settings")
                }
                
                Section {
                    Button(action: generateContent) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                                Text("Generating...")
                            } else {
                                Image(systemName: "brain.head.profile")
                                Text("Generate Learning Set")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .bold()
                    }
                    .disabled(title.isEmpty || isGenerating)
                    .listRowBackground(
                        (title.isEmpty || isGenerating) ? Color.gray : Color.accentColor
                    )
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Create Study Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateContent() {
        isGenerating = true
        
        Task {
            do {
                let service = AIService.shared
                let topicDescription = "\(suggestion.title): \(suggestion.description)"
                
                let guide = try await service.generateTopicGuide(
                    topic: topicDescription,
                    style: .paragraph,
                    wordCount: Int(summaryWordCount),
                    difficulty: difficulty
                )
                
                let questionsData = try await service.generateTopicQuestions(
                    topic: topicDescription,
                    count: Int(questionCount),
                    difficulty: difficulty
                )
                
                let flashcardsData = try await service.generateTopicFlashcards(
                    topic: topicDescription,
                    count: Int(flashcardCount),
                    difficulty: difficulty
                )
                
                let newSet = StudySet(title: title, originalText: topicDescription, summary: guide, mode: .topic)
                modelContext.insert(newSet)
                
                for q in questionsData {
                    let question = Question(prompt: q.question, answer: q.answer, options: q.options, explanation: q.explanation)
                    question.studySet = newSet
                }
                
                for f in flashcardsData {
                    let card = Flashcard(front: f.front, back: f.back)
                    card.studySet = newSet
                }
                
                // Record study set creation for gamification
                gamificationManager.recordStudySetCreated(profile: profile, context: modelContext)
                
                await MainActor.run {
                    isGenerating = false
                    dismiss()
                }
                
            } catch {
                print("Error generating content: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TopicSuggestionsView()
    }
    .modelContainer(for: [StudySet.self, UserProfile.self], inMemory: true)
}
