import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var gamificationManager = GamificationManager.shared
    @EnvironmentObject private var guideManager: GuideManager
    
    let flashcards: [Flashcard]
    @State private var currentIndex = 0
    @State private var cardsStudied = 0
    @State private var cardsMastered = 0
    @State private var hasRecordedSession = false
    @State private var showSessionComplete = false
    @State private var studiedCardIds: Set<UUID> = []
    @State private var masteredCardIds: Set<UUID> = []
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        return gamificationManager.getOrCreateProfile(context: modelContext)
    }
    
    var body: some View {
        VStack {
            if flashcards.isEmpty {
                Text("No flashcards available.")
                    .foregroundColor(.secondary)
            } else if showSessionComplete {
                sessionCompleteView
            } else {
                // Progress Stats Bar
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(cardsStudied) Studied")
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
                        Text("\(cardsMastered) Mastered")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                TabView(selection: $currentIndex) {
                    ForEach(flashcards.indices, id: \.self) { index in
                        FlashcardView(
                            card: flashcards[index],
                            isStudied: studiedCardIds.contains(flashcards[index].id),
                            isMastered: masteredCardIds.contains(flashcards[index].id),
                            onStudied: { markStudied(flashcards[index].id) },
                            onMastered: { markMastered(flashcards[index].id) }
                        )
                        .tag(index)
                        .padding()
                        .guideTarget(.flashcardsDeck)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Bottom Bar
                HStack {
                    // Card Counter
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack")
                            .font(.caption)
                        Text("\(currentIndex + 1) of \(flashcards.count)")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if cardsStudied > 0 {
                        Button(action: {
                            finishSession()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Finish Session")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Flashcards")
        .onDisappear {
            if cardsStudied > 0 && !hasRecordedSession {
                finishSession()
            }
            if guideManager.currentStep == .exploreFlashcards {
                guideManager.advanceAfterVisitedFlashcards()
            }
        }
    }
    
    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Session Complete!")
                .font(.title.bold())
            
            VStack(spacing: 16) {
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("\(cardsStudied)")
                            .font(.title2.bold())
                        Text("Studied")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(cardsMastered)")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                        Text("Mastered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // XP Earned
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.blue)
                    Text("+\(calculateXPEarned()) XP")
                        .font(.headline.bold())
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .padding()
    }
    
    private func markStudied(_ cardId: UUID) {
        guard !studiedCardIds.contains(cardId) else { return }
        studiedCardIds.insert(cardId)
        cardsStudied += 1
    }
    
    private func markMastered(_ cardId: UUID) {
        guard !masteredCardIds.contains(cardId) else { return }
        masteredCardIds.insert(cardId)
        cardsMastered += 1
        // Also mark as studied if not already
        if !studiedCardIds.contains(cardId) {
            studiedCardIds.insert(cardId)
            cardsStudied += 1
        }
    }
    
    private func finishSession() {
        guard !hasRecordedSession && cardsStudied > 0 else { return }
        hasRecordedSession = true
        
        gamificationManager.recordFlashcardStudied(
            count: cardsStudied,
            mastered: cardsMastered,
            profile: profile,
            context: modelContext
        )
        
        showSessionComplete = true
    }
    
    private func calculateXPEarned() -> Int {
        var xp = cardsStudied * XPRewards.flashcardStudied
        xp += cardsMastered * XPRewards.flashcardMastered
        let multiplier = XPRewards.streakMultiplier(for: profile.currentStreak)
        return Int(Double(xp) * multiplier)
    }
}

struct FlashcardView: View {
    let card: Flashcard
    var isStudied: Bool = false
    var isMastered: Bool = false
    var onStudied: (() -> Void)?
    var onMastered: (() -> Void)?
    
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
                withAnimation(.spring()) {
                    isFlipped.toggle()
                    if isFlipped && !isStudied {
                        onStudied?()
                    }
                }
            }
            
            // Mark as mastered button (only after flipping, if not already mastered)
            if isFlipped && !isMastered {
                Button(action: {
                    onMastered?()
                }) {
                    Label("I Know This!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
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
