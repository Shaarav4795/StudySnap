import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var guideManager: GuideManager
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)
                
                CreateSetPage()
                    .tag(1)
                
                TutorialFlashcardPage()
                    .tag(2)
                
                TutorialQuizPage()
                    .tag(3)
                
                GamificationPage()
                    .tag(4)
                
                NavigationPage()
                    .tag(5)
                
                SummaryPage(onFinish: {
                    hasSeenTutorial = true
                    guideManager.startIfNeededAfterTutorial()
                    dismiss()
                })
                .tag(6)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        HapticsManager.shared.playTap()
                        hasSeenTutorial = true
                        guideManager.startIfNeededAfterTutorial()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Pages

struct WelcomePage: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(themeManager.primaryGradient.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(themeManager.primaryGradient)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                Text("Welcome to StudySnap")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Your personal AI study companion.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 20) {
                FeatureItem(icon: "sparkles", text: "AI-Generated Quizzes")
                FeatureItem(icon: "rectangle.stack.fill", text: "Smart Flashcards")
                FeatureItem(icon: "chart.bar.fill", text: "Track Progress")
            }
            .padding(.top, 20)
            
            Spacer()
            
            Text("Swipe to begin →")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 60)
        }
        .padding()
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 30)
            
            Text(text)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 24)
    }
}

struct CreateSetPage: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Creating Study Sets")
                    .font(.title2.bold())
                    .padding(.top, 60)
                
                Text("Choose how you want to learn. StudySnap offers two powerful modes:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 24) {
                    // Content Mode
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("From Content")
                                .font(.title3.bold())
                        }
                        
                        Text("Best for studying specific material like textbook chapters or lecture notes.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Paste Text")
                                    .font(.headline)
                                Text("Copy text from any app and paste it directly.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Scan Documents")
                                    .font(.headline)
                                Text("Use your camera to scan physical pages instantly.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    // Topic Mode
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                            Text("Learn Topic")
                                .font(.title3.bold())
                        }
                        
                        Text("Don't have notes? Just enter a topic and let AI teach you.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("AI Generation")
                                    .font(.headline)
                                Text("Enter 'Photosynthesis' or 'French Revolution' and get a full study set.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title)
                                .foregroundColor(.green)
                            Text("Customize Your Set")
                                .font(.title3.bold())
                        }
                        
                        Text("Tailor your study experience with these settings:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            SettingRow(icon: "text.alignleft", title: "Summary Style", description: "Choose between Paragraphs or Bullet Points.")
                            SettingRow(icon: "textformat.size", title: "Word Count", description: "Set the length of your summary.")
                            SettingRow(icon: "gauge.high", title: "Difficulty", description: "Adjust complexity (Beginner to Advanced).")
                            SettingRow(icon: "square.grid.2x2", title: "Icon", description: "Pick a visual icon for your set.")
                            SettingRow(icon: "rectangle.stack", title: "Flashcards", description: "Choose how many cards to generate.")
                            SettingRow(icon: "questionmark.circle", title: "Questions", description: "Set the number of quiz questions.")
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .font(.system(size: 16))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TutorialFlashcardPage: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isFlipped = false
    @State private var showHand = true
    @State private var isMastered = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Master with Flashcards")
                .font(.title2.bold())
                .padding(.top, 60)
            
            Text("Tap the card to flip it.\nMark as 'Mastered' when you know it.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            ZStack {
                // Card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isMastered ? Color.green.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: isMastered ? Color.green.opacity(0.2) : .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isMastered ? Color.green : Color.clear, lineWidth: 2)
                        )
                    
                    if isFlipped {
                        VStack {
                            Text("Paris")
                                .font(.largeTitle.bold())
                                .foregroundColor(themeManager.primaryColor)
                            Text("(Back)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        VStack {
                            Text("Capital of France")
                                .font(.title2)
                                .multilineTextAlignment(.center)
                            Text("(Front)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    
                    if isMastered {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                                    .padding()
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 260)
                .padding(.horizontal, 40)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .onTapGesture {
                    HapticsManager.shared.playTap()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isFlipped.toggle()
                        showHand = false
                    }
                }
                
                // Hand hint
                if showHand {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 50))
                        .foregroundColor(themeManager.primaryColor)
                        .offset(x: 60, y: 60)
                        .transition(.opacity)
                        .shadow(radius: 2)
                }
            }
            
            if isFlipped && !isMastered {
                Button(action: {
                    HapticsManager.shared.playTap()
                    withAnimation {
                        isMastered = true
                        isFlipped = false // Flip back to show front with mastered state
                    }
                }) {
                    Label("I Know This!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(20)
                }
                .transition(.scale.combined(with: .opacity))
            } else if isMastered {
                Text("Mastered!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.vertical, 12)
                    .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
        }
    }
}

struct TutorialQuizPage: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedAnswer: String?
    @State private var isCorrect = false
    @State private var showExplanation = false
    
    let question = "What is the powerhouse of the cell?"
    let answers = ["Nucleus", "Mitochondria", "Ribosome", "Cytoplasm"]
    let correct = "Mitochondria"
    let explanation = "Mitochondria are known as the powerhouse of the cell because they generate most of the cell's supply of adenosine triphosphate (ATP), used as a source of chemical energy."
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Interactive Quizzes")
                    .font(.title2.bold())
                    .padding(.top, 60)
                
                Text("Test your knowledge and get instant feedback.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Question Card
                    Text(question)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Answers
                    VStack(spacing: 12) {
                        ForEach(Array(answers.enumerated()), id: \.element) { index, answer in
                            Button(action: {
                                HapticsManager.shared.playTap()
                                withAnimation {
                                    selectedAnswer = answer
                                    isCorrect = (answer == correct)
                                    showExplanation = true
                                }
                            }) {
                                HStack(spacing: 15) {
                                    // Letter Circle
                                    ZStack {
                                        Circle()
                                            .fill(circleColor(for: answer))
                                            .frame(width: 36, height: 36)
                                        
                                        Text(["A", "B", "C", "D"][index])
                                            .font(.headline)
                                            .foregroundColor(circleTextColor(for: answer))
                                    }
                                    
                                    Text(answer)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if showExplanation {
                                        if answer == correct {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        } else if answer == selectedAnswer {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(backgroundColor(for: answer))
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(borderColor(for: answer), lineWidth: showExplanation && (answer == correct || answer == selectedAnswer) ? 2 : 0)
                                )
                            }
                            .disabled(showExplanation)
                        }
                    }
                    
                    // Explanation Box
                    if showExplanation {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Explanation", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(explanation)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.bottom, 40)
        }
    }
    
    func circleColor(for answer: String) -> Color {
        if showExplanation {
            if answer == correct { return .green }
            if answer == selectedAnswer { return .red }
            return .gray.opacity(0.2)
        }
        return themeManager.primaryColor.opacity(0.1)
    }
    
    func circleTextColor(for answer: String) -> Color {
        if showExplanation {
            if answer == correct || answer == selectedAnswer { return .white }
            return .secondary
        }
        return themeManager.primaryColor
    }
    
    func backgroundColor(for answer: String) -> Color {
        if showExplanation {
            if answer == correct { return Color.green.opacity(0.1) }
            if answer == selectedAnswer { return Color.red.opacity(0.1) }
        }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    func borderColor(for answer: String) -> Color {
        if showExplanation {
            if answer == correct { return .green }
            if answer == selectedAnswer { return .red }
        }
        return .clear
    }
}

struct GamificationPage: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Stay Motivated")
                .font(.title2.bold())
                .padding(.top, 60)
            
            HStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Streaks")
                        .font(.headline)
                    Text("Study daily to keep your fire burning!")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                VStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                    Text("Coins")
                        .font(.headline)
                    Text("Earn coins to buy cool themes.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Level Up")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                
                HStack {
                    Text("Level 1")
                        .font(.caption.bold())
                    Spacer()
                    Text("50/100 XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 10)
                        
                        Capsule()
                            .fill(themeManager.horizontalGradient)
                            .frame(width: geometry.size.width * 0.5, height: 10)
                    }
                }
                .frame(height: 10)
                
                Text("Complete quizzes and study sessions to earn XP and unlock new avatars!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Text("How to Earn:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Complete a Quiz")
                        Spacer()
                        Text("+50 XP")
                            .font(.caption.bold())
                            .foregroundColor(themeManager.primaryColor)
                    }
                    
                    HStack {
                        Image(systemName: "rectangle.stack.fill")
                            .foregroundColor(.blue)
                        Text("Master a Flashcard")
                        Spacer()
                        Text("+10 XP")
                            .font(.caption.bold())
                            .foregroundColor(themeManager.primaryColor)
                    }
                    
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Daily Streak")
                        Spacer()
                        Text("1.5x Multiplier")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

struct NavigationPage: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Navigating StudySnap")
                    .font(.title2.bold())
                    .padding(.top, 60)
                
                Text("Everything you need is just a tap away.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 24) {
                    // Home
                    HStack(spacing: 16) {
                        Image(systemName: "books.vertical.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Home")
                                .font(.headline)
                            Text("View and manage all your study sets.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Create
                    HStack(spacing: 16) {
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(themeManager.primaryColor)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create")
                                .font(.headline)
                            Text("Tap the + button to create new sets.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    
                    // Profile
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.purple)
                            .frame(width: 50, height: 50)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile & Shop")
                                .font(.headline)
                            Text("Track progress and spend your coins.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
}

struct SummaryPage: View {
    var onFinish: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 150, height: 150)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
            
            Text("You're Ready!")
                .font(.largeTitle.bold())
            
            Text("Start creating your first study set now.")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Button(action: {
                HapticsManager.shared.playTap()
                onFinish()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.primaryColor)
                    .cornerRadius(16)
                    .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    TutorialView()
        .environmentObject(ThemeManager.shared)
}
