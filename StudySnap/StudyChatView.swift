import SwiftUI
import SwiftData

// MARK: - Study Chat View (Tutor)

struct StudyChatView: View {
    let studySet: StudySet
    @Environment(\.modelContext) private var modelContext
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var showingFlashcardPreview = false
    @State private var pendingFlashcards: [(front: String, back: String)] = []
    @State private var selectedMessageForAction: ChatMessage?
    @State private var quickPrompts: [QuickPrompt] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showClearConfirmation = false
    
    // For smooth typing indicator
    @State private var typingDots = ""
    @State private var typingTimer: Timer?
    
    private var sortedMessages: [ChatMessage] {
        studySet.sortedChatHistory
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Persistent header actions
            HStack {
                Spacer()
                Button {
                    showClearConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("New Chat")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .disabled(sortedMessages.isEmpty)
                .accessibilityLabel("Clear Chat")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Welcome message if no history
                        if sortedMessages.isEmpty && !isLoading {
                            WelcomeMessageView(studySetTitle: studySet.title)
                                .id("welcome")
                        }
                        
                        ForEach(sortedMessages) { message in
                            ChatBubbleView(
                                message: message,
                                onSaveAsFlashcard: {
                                    selectedMessageForAction = message
                                    Task {
                                        await convertMessageToFlashcards(message)
                                    }
                                }
                            )
                            .id(message.id)
                        }
                        
                        // Typing indicator
                        if isLoading {
                            TypingIndicatorView()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    scrollProxy = proxy
                    loadQuickPrompts()
                }
                .onChange(of: sortedMessages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isLoading) { _, loading in
                    if loading {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            
            Divider()
            
            // Quick prompts
            QuickPromptsBar(
                prompts: quickPrompts,
                onSelect: { prompt in
                    messageText = prompt.prompt
                    sendMessage(format: prompt.format)
                }
            )
            
            // Input bar
            ChatInputBar(
                text: $messageText,
                isLoading: isLoading,
                onSend: { sendMessage() },
                onTextChange: { _ in
                    updateQuickPrompts()
                }
            )
        }
        .background(Color(.systemGroupedBackground))
        .confirmationDialog(
            "Clear Chat History?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Messages", role: .destructive) {
                clearChatHistory()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete all messages in this conversation. This cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingFlashcardPreview) {
            FlashcardPreviewSheet(
                flashcards: pendingFlashcards,
                studySet: studySet,
                onConfirm: { selected in
                    addFlashcardsToSet(selected)
                    showingFlashcardPreview = false
                    pendingFlashcards = []
                },
                onCancel: {
                    showingFlashcardPreview = false
                    pendingFlashcards = []
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage(format: AIService.TutorResponseFormat = .standard) {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        
        // Strip format markers from display text
        let displayText = text.replacingOccurrences(of: "\\[FORMAT:\\w+\\]\\s*", with: "", options: .regularExpression)
        
        // Add user message
        let userMessage = ChatMessage(text: displayText, isUser: true)
        userMessage.studySet = studySet
        studySet.chatHistory.append(userMessage)
        modelContext.insert(userMessage)
        
        messageText = ""
        isLoading = true
        
        // Trigger haptic
        HapticsManager.shared.lightImpact()
        
        Task {
            await generateResponse(for: text, format: format)
        }
    }
    
    private func generateResponse(for userText: String, format: AIService.TutorResponseFormat = .standard) async {
        do {
            // Build context with original text and summary only
            let context = AIService.TutorContext.create(from: studySet)
            
            // Build conversation history
            let history = sortedMessages.map { msg in
                AIService.ChatTurn(
                    role: msg.isUser ? "user" : "assistant",
                    content: msg.text
                )
            }
            
            let response = try await AIService.shared.performChat(
                messages: history,
                context: context,
                format: format
            )
            
            await MainActor.run {
                // Add AI response
                let aiMessage = ChatMessage(text: response, isUser: false)
                aiMessage.studySet = studySet
                studySet.chatHistory.append(aiMessage)
                modelContext.insert(aiMessage)
                
                isLoading = false
                
                // Success haptic
                HapticsManager.shared.success()
                
                // Update quick prompts based on new context
                loadQuickPrompts()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to get response: \(error.localizedDescription)"
                showError = true
                HapticsManager.shared.error()
            }
        }
    }
    
    private func convertMessageToFlashcards(_ message: ChatMessage) async {
        guard !message.isUser else { return }
        
        isLoading = true
        
        do {
            let context = AIService.TutorContext.create(from: studySet)
            
            let flashcards = try await AIService.shared.convertToFlashcards(
                aiResponse: message.text,
                context: context
            )
            
            await MainActor.run {
                isLoading = false
                pendingFlashcards = flashcards
                showingFlashcardPreview = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to create flashcards: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func addFlashcardsToSet(_ flashcards: [(front: String, back: String)]) {
        for card in flashcards {
            let newCard = Flashcard(front: card.front, back: card.back)
            newCard.studySet = studySet
            studySet.flashcards.append(newCard)
            modelContext.insert(newCard)
        }
        
        HapticsManager.shared.success()
    }
    
    private func loadQuickPrompts() {
        let context = AIService.TutorContext.create(from: studySet)
        
        let history = sortedMessages.suffix(4).map { msg in
            AIService.ChatTurn(
                role: msg.isUser ? "user" : "assistant",
                content: msg.text
            )
        }
        
        Task { @MainActor in
            quickPrompts = await AIService.shared.generateQuickPrompts(
                partialInput: messageText,
                recentMessages: Array(history),
                context: context
            )
        }
    }
    
    private func updateQuickPrompts() {
        // Debounce quick prompt updates
        loadQuickPrompts()
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if isLoading {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastMessage = sortedMessages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func clearChatHistory() {
        for message in studySet.chatHistory {
            modelContext.delete(message)
        }
        studySet.chatHistory.removeAll()
        HapticsManager.shared.lightImpact()
    }
}

// MARK: - Welcome Message

private struct WelcomeMessageView: View {
    let studySetTitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Study Tutor")
                .font(.title2.bold())
            
            Text("Ask me anything about \"\(studySetTitle)\". I can explain concepts, create memory tricks, quiz you, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Chat Bubble

private struct ChatBubbleView: View {
    let message: ChatMessage
    let onSaveAsFlashcard: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Message bubble
                Group {
                    if message.isUser {
                        Text(message.text)
                            .foregroundStyle(.white)
                    } else {
                        FormattedMessageView(text: message.text)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isUser
                        ? Color.accentColor
                        : Color(.secondarySystemGroupedBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contextMenu {
                    if !message.isUser {
                        Button {
                            onSaveAsFlashcard()
                        } label: {
                            Label("Save as Flashcard", systemImage: "rectangle.on.rectangle.angled")
                        }
                    }
                    
                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Card Type for Section Display

private enum SectionCardType: String {
    case mnemonic = "MNEMONIC"
    case steps = "STEPS"
    case scenario = "SCENARIO"
    case simple = "SIMPLE"
    case keypoints = "KEYPOINTS"
    case analogy = "ANALOGY"
    case mistakes = "MISTAKES"
    case compare = "COMPARE"
    case breakdown = "BREAKDOWN"
    case mapping = "MAPPING"
    case connection = "CONNECTION"
    case takeaway = "TAKEAWAY"
    case tip = "TIP"
    case summary = "SUMMARY"
    case insight = "INSIGHT"
    case example = "EXAMPLE"
    
    var icon: String {
        switch self {
        case .mnemonic: return "brain.head.profile"
        case .steps: return "list.number"
        case .scenario: return "theatermasks"
        case .simple: return "lightbulb.min"
        case .keypoints: return "list.bullet"
        case .analogy: return "arrow.triangle.branch"
        case .mistakes: return "exclamationmark.triangle"
        case .compare: return "arrow.left.arrow.right"
        case .breakdown: return "puzzlepiece"
        case .mapping: return "arrow.left.arrow.right.circle"
        case .connection: return "link"
        case .takeaway: return "star"
        case .tip: return "lightbulb"
        case .summary: return "text.alignleft"
        case .insight: return "sparkles"
        case .example: return "doc.text.magnifyingglass"
        }
    }
    
    var color: Color {
        switch self {
        case .mnemonic: return .purple
        case .steps: return .blue
        case .scenario: return .orange
        case .simple: return .green
        case .keypoints: return .indigo
        case .analogy: return .teal
        case .mistakes: return .red
        case .compare: return .cyan
        case .breakdown: return .purple
        case .mapping: return .teal
        case .connection: return .orange
        case .takeaway: return .yellow
        case .tip: return .mint
        case .summary: return .gray
        case .insight: return .pink
        case .example: return .blue
        }
    }
}

// MARK: - Formatted Message View (Complete Markdown Renderer)

private struct FormattedMessageView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }
    
    // MARK: - Block Types
    
    private enum TextBlock {
        case paragraph(String)
        case header(String, level: Int)
        case bulletList([String])
        case numberedList([String])
        case table(headers: [String], rows: [[String]])
        case checkItem(checked: Bool, text: String)
        // New specialized blocks
        case sectionCard(type: SectionCardType, title: String, content: [String])
        case mappingList(items: [(left: String, right: String)])
    }
    
    // MARK: - Parsing
    
    private func parseBlocks() -> [TextBlock] {
        var blocks: [TextBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentBullets: [String] = []
        var currentNumbers: [String] = []
        var inTable = false
        var tableHeaders: [String] = []
        var tableRows: [[String]] = []
        var currentMappings: [(String, String)] = []
        var currentSectionType: SectionCardType? = nil
        var currentSectionContent: [String] = []
        
        func flushPending() {
            if !currentBullets.isEmpty {
                blocks.append(.bulletList(currentBullets))
                currentBullets = []
            }
            if !currentNumbers.isEmpty {
                blocks.append(.numberedList(currentNumbers))
                currentNumbers = []
            }
            if !currentMappings.isEmpty {
                blocks.append(.mappingList(items: currentMappings))
                currentMappings = []
            }
            if let sectionType = currentSectionType, !currentSectionContent.isEmpty {
                blocks.append(.sectionCard(type: sectionType, title: sectionType.rawValue, content: currentSectionContent))
                currentSectionType = nil
                currentSectionContent = []
            }
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for bare section labels like "SUMMARY:" without brackets
            if let bareMatch = trimmed.range(of: "^(SUMMARY|INSIGHT|TAKEAWAY|TIP):\\s*", options: .regularExpression) {
                let labelPart = String(trimmed[bareMatch])
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .uppercased()
                if let cardType = SectionCardType(rawValue: labelPart) {
                    flushPending()
                    if inTable {
                        blocks.append(.table(headers: tableHeaders, rows: tableRows))
                        tableHeaders = []
                        tableRows = []
                        inTable = false
                    }
                    currentSectionType = cardType
                    currentSectionContent = []
                    
                    let afterLabel = String(trimmed[bareMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !afterLabel.isEmpty {
                        currentSectionContent.append(afterLabel)
                    }
                    continue
                }
            }
            
            // Check for section tags [MNEMONIC], [STEPS], etc. - either alone or with text after
            if let tagMatch = trimmed.range(of: "^\\[([A-Z]+)\\]", options: .regularExpression) {
                let tagPart = String(trimmed[tagMatch])
                let tagName = tagPart
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                
                // Check if this is a valid section tag
                if let cardType = SectionCardType(rawValue: tagName) {
                    flushPending()
                    if inTable {
                        blocks.append(.table(headers: tableHeaders, rows: tableRows))
                        tableHeaders = []
                        tableRows = []
                        inTable = false
                    }
                    currentSectionType = cardType
                    currentSectionContent = []
                    
                    // Check if there's text after the tag on the same line
                    let afterTag = String(trimmed[tagMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !afterTag.isEmpty {
                        currentSectionContent.append(afterTag)
                    }
                    continue
                }
            }
            
            // If inside a section, collect content
            if currentSectionType != nil && !trimmed.isEmpty {
                // Check if it's a new section tag (with or without inline text)
                if let tagMatch = trimmed.range(of: "^\\[([A-Z]+)\\]", options: .regularExpression) {
                    let tagPart = String(trimmed[tagMatch])
                    let tagName = tagPart
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                    if let newType = SectionCardType(rawValue: tagName) {
                        // Flush current section and start new one
                        if !currentSectionContent.isEmpty {
                            blocks.append(.sectionCard(type: currentSectionType!, title: currentSectionType!.rawValue, content: currentSectionContent))
                        }
                        currentSectionType = newType
                        currentSectionContent = []
                        
                        // Check if there's text after the tag
                        let afterTag = String(trimmed[tagMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
                        if !afterTag.isEmpty {
                            currentSectionContent.append(afterTag)
                        }
                        continue
                    }
                }
                currentSectionContent.append(trimmed)
                continue
            }
            
            // Check for mapping arrows (→ or ↔ or <->)
            if trimmed.contains("→") || trimmed.contains("↔") || trimmed.contains("<->") {
                flushPending()
                let parts = trimmed
                    .replacingOccurrences(of: "↔", with: "→")
                    .replacingOccurrences(of: "<->", with: "→")
                    .components(separatedBy: "→")
                if parts.count == 2 {
                    let left = parts[0].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
                    let right = parts[1].trimmingCharacters(in: .whitespaces)
                    currentMappings.append((left, right))
                    continue
                }
            }
            
            // Check for table row
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                flushPending()
                
                // Skip separator rows
                if trimmed.contains("---") || trimmed.contains("---|") {
                    continue
                }
                
                let cells = trimmed
                    .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                if !inTable {
                    tableHeaders = cells
                    inTable = true
                } else {
                    tableRows.append(cells)
                }
                continue
            } else if inTable {
                blocks.append(.table(headers: tableHeaders, rows: tableRows))
                tableHeaders = []
                tableRows = []
                inTable = false
            }
            
            // Check for checkmarks (✓ or ✗)
            if trimmed.hasPrefix("✓") || trimmed.hasPrefix("✗") {
                flushPending()
                let isChecked = trimmed.hasPrefix("✓")
                let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                blocks.append(.checkItem(checked: isChecked, text: content))
                continue
            }
            
            // Check for headers
            if trimmed.lowercased().hasPrefix("[correct approach]") {
                flushPending()
                blocks.append(.header("Correct approach", level: 2))
                continue
            }
            if trimmed.hasPrefix("###") {
                flushPending()
                let headerText = trimmed.replacingOccurrences(of: "^#{1,3}\\s*", with: "", options: .regularExpression)
                blocks.append(.header(headerText, level: 3))
                continue
            }
            if trimmed.hasPrefix("##") {
                flushPending()
                let headerText = trimmed.replacingOccurrences(of: "^#{1,2}\\s*", with: "", options: .regularExpression)
                blocks.append(.header(headerText, level: 2))
                continue
            }
            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") {
                flushPending()
                let headerText = trimmed.replacingOccurrences(of: "^#\\s*", with: "", options: .regularExpression)
                blocks.append(.header(headerText, level: 1))
                continue
            }
            
            // Check for bullets (but not if it's a mapping)
            if (trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*")) && !trimmed.contains("→") {
                // Special handling for comparison bullets like "• Aspect: left; right"
                if let compMatch = trimmed.range(of: "^•\\s*([^:]+):\\s*(.+);\\s*(.+)$", options: .regularExpression) {
                    let full = String(trimmed[compMatch])
                    let parts = full
                        .replacingOccurrences(of: "^•\\s*", with: "", options: .regularExpression)
                        .components(separatedBy: ":")
                    if parts.count >= 2 {
                        let aspect = parts[0].trimmingCharacters(in: .whitespaces)
                        let rest = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                        let halves = rest.components(separatedBy: ";")
                        if halves.count >= 2 {
                            let left = halves[0].trimmingCharacters(in: .whitespaces)
                            let right = halves[1].trimmingCharacters(in: .whitespaces)
                            currentMappings.append(("\(aspect): \(left)", right))
                            continue
                        }
                    }
                }

                if !currentNumbers.isEmpty {
                    blocks.append(.numberedList(currentNumbers))
                    currentNumbers = []
                }
                if !currentMappings.isEmpty {
                    blocks.append(.mappingList(items: currentMappings))
                    currentMappings = []
                }
                var bulletText = trimmed
                if bulletText.hasPrefix("•") || bulletText.hasPrefix("-") {
                    bulletText = String(bulletText.dropFirst()).trimmingCharacters(in: .whitespaces)
                } else if bulletText.hasPrefix("* ") {
                    bulletText = String(bulletText.dropFirst(2))
                } else if bulletText.hasPrefix("*") && !bulletText.hasPrefix("**") {
                    bulletText = String(bulletText.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                currentBullets.append(bulletText)
                continue
            }
            
            // Check for numbered list
            if let match = trimmed.range(of: "^\\d+\\.\\s*", options: .regularExpression) {
                // Only flush bullets/mappings, not other numbers
                if !currentBullets.isEmpty {
                    blocks.append(.bulletList(currentBullets))
                    currentBullets = []
                }
                if !currentMappings.isEmpty {
                    blocks.append(.mappingList(items: currentMappings))
                    currentMappings = []
                }
                let numberText = String(trimmed[match.upperBound...])
                currentNumbers.append(numberText)
                continue
            }
            
            // Regular paragraph
            flushPending()
            
            if !trimmed.isEmpty {
                blocks.append(.paragraph(trimmed))
            }
        }
        
        // Flush remaining
        flushPending()
        if inTable && !tableHeaders.isEmpty {
            blocks.append(.table(headers: tableHeaders, rows: tableRows))
        }
        
        return blocks
    }
    
    // MARK: - Block Rendering
    
    @ViewBuilder
    private func renderBlock(_ block: TextBlock) -> some View {
        switch block {
        case .paragraph(let text):
            renderInlineMarkdown(text)
            
        case .header(let text, let level):
            renderInlineMarkdown(text)
                .font(level == 1 ? .headline : (level == 2 ? .subheadline.bold() : .subheadline.bold()))
                .foregroundStyle(.primary)
            
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        renderInlineMarkdown(item)
                    }
                }
            }
            
        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 24, height: 24)
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.accentColor)
                        }
                        renderInlineMarkdown(item)
                            .padding(.top, 2)
                    }
                }
            }
            
        case .table(let headers, let rows):
            ComparisonTableView(headers: headers, rows: rows)
            
        case .checkItem(let checked, let text):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(checked ? .green : .red)
                    .font(.body)
                renderInlineMarkdown(text)
            }
            .padding(.vertical, 4)
            
        case .sectionCard(let type, _, let content):
            SectionCardView(type: type, content: content)
            
        case .mappingList(let items):
            MappingListView(items: items)
        }
    }
    
    // MARK: - Inline Markdown Rendering
    
    private func renderInlineMarkdown(_ text: String) -> Text {
        Text(parseAttributedString(text))
    }
    
    private func parseAttributedString(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text
        
        while !remaining.isEmpty {
            // Find the first match among all patterns
            var firstMatchStart: String.Index? = nil
            var matchType: String = ""
            
            // Check for bold (**text**)
            if let boldRange = remaining.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
                if firstMatchStart == nil || boldRange.lowerBound < firstMatchStart! {
                    firstMatchStart = boldRange.lowerBound
                    matchType = "bold"
                }
            }
            
            // Check for italic (*text*) - but not **
            if let italicRange = remaining.range(of: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", options: .regularExpression) {
                if firstMatchStart == nil || italicRange.lowerBound < firstMatchStart! {
                    firstMatchStart = italicRange.lowerBound
                    matchType = "italic"
                }
            }
            
            // Check for fraction (a/b where a and b are numbers, but NOT followed by a word like "people")
            // Only match fractions that are standalone or followed by punctuation/whitespace/end
            if let fracRange = remaining.range(of: "(?<![a-zA-Z])(\\d+)/(\\d+)(?![a-zA-Z]|\\s+[a-zA-Z])", options: .regularExpression) {
                // Additional check: make sure it's not followed by a word (like "5/6 people")
                let afterFrac = remaining[fracRange.upperBound...]
                let isFollowedByWord = afterFrac.hasPrefix(" ") && afterFrac.dropFirst().first?.isLetter == true
                if !isFollowedByWord {
                    if firstMatchStart == nil || fracRange.lowerBound < firstMatchStart! {
                        firstMatchStart = fracRange.lowerBound
                        matchType = "fraction"
                    }
                }
            }
            
            // Check for superscript (x² or x^2)
            if let supRange = remaining.range(of: "([a-zA-Z0-9])([²³⁴⁵⁶⁷⁸⁹⁰¹]|\\^\\d+)", options: .regularExpression) {
                if firstMatchStart == nil || supRange.lowerBound < firstMatchStart! {
                    firstMatchStart = supRange.lowerBound
                    matchType = "superscript"
                }
            }
            
            // Check for arrows
            if let arrowRange = remaining.range(of: "[→↔←]") {
                if firstMatchStart == nil || arrowRange.lowerBound < firstMatchStart! {
                    firstMatchStart = arrowRange.lowerBound
                    matchType = "arrow"
                }
            }
            
            guard let matchStart = firstMatchStart else {
                // No more matches, append rest
                result.append(AttributedString(remaining))
                break
            }
            
            // Append text before match
            let beforeMatch = String(remaining[..<matchStart])
            if !beforeMatch.isEmpty {
                result.append(AttributedString(beforeMatch))
            }
            
            // Handle the match
            switch matchType {
            case "bold":
                if let boldRange = remaining.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
                    let boldContent = String(remaining[boldRange])
                        .replacingOccurrences(of: "**", with: "")
                    var boldAttr = AttributedString(boldContent)
                    boldAttr.font = .body.bold()
                    result.append(boldAttr)
                    remaining = String(remaining[boldRange.upperBound...])
                }
                
            case "italic":
                if let italicRange = remaining.range(of: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", options: .regularExpression) {
                    var italicContent = String(remaining[italicRange])
                    // Remove single asterisks
                    if italicContent.hasPrefix("*") { italicContent.removeFirst() }
                    if italicContent.hasSuffix("*") { italicContent.removeLast() }
                    var italicAttr = AttributedString(italicContent)
                    italicAttr.font = .body.italic()
                    result.append(italicAttr)
                    remaining = String(remaining[italicRange.upperBound...])
                }
                
            case "fraction":
                if let fracRange = remaining.range(of: "(?<![a-zA-Z])(\\d+)/(\\d+)(?![a-zA-Z]|\\s+[a-zA-Z])", options: .regularExpression) {
                    let fracString = String(remaining[fracRange])
                    // Try to convert to unicode fraction or display nicely
                    let parts = fracString.components(separatedBy: "/")
                    if parts.count == 2 {
                        let unicodeFraction = convertToUnicodeFraction(parts[0], parts[1])
                        var fracAttr = AttributedString(unicodeFraction)
                        fracAttr.font = .body
                        result.append(fracAttr)
                    }
                    remaining = String(remaining[fracRange.upperBound...])
                }
                
            case "superscript":
                if let supRange = remaining.range(of: "([a-zA-Z0-9])([²³⁴⁵⁶⁷⁸⁹⁰¹]|\\^\\d+)", options: .regularExpression) {
                    var supContent = String(remaining[supRange])
                    // Convert ^2 style to unicode
                    supContent = supContent.replacingOccurrences(of: "^0", with: "⁰")
                    supContent = supContent.replacingOccurrences(of: "^1", with: "¹")
                    supContent = supContent.replacingOccurrences(of: "^2", with: "²")
                    supContent = supContent.replacingOccurrences(of: "^3", with: "³")
                    supContent = supContent.replacingOccurrences(of: "^4", with: "⁴")
                    supContent = supContent.replacingOccurrences(of: "^5", with: "⁵")
                    supContent = supContent.replacingOccurrences(of: "^6", with: "⁶")
                    supContent = supContent.replacingOccurrences(of: "^7", with: "⁷")
                    supContent = supContent.replacingOccurrences(of: "^8", with: "⁸")
                    supContent = supContent.replacingOccurrences(of: "^9", with: "⁹")
                    result.append(AttributedString(supContent))
                    remaining = String(remaining[supRange.upperBound...])
                }
                
            case "arrow":
                if let arrowRange = remaining.range(of: "[→↔←]") {
                    let arrow = String(remaining[arrowRange])
                    var arrowAttr = AttributedString(arrow)
                    arrowAttr.foregroundColor = .accentColor
                    result.append(arrowAttr)
                    remaining = String(remaining[arrowRange.upperBound...])
                }
                
            default:
                result.append(AttributedString(remaining))
                break
            }
        }
        
        return result
    }
    
    private func convertToUnicodeFraction(_ num: String, _ denom: String) -> String {
        // Common fractions
        let commonFractions: [String: String] = [
            "1/2": "½", "1/3": "⅓", "2/3": "⅔",
            "1/4": "¼", "3/4": "¾", "1/5": "⅕",
            "2/5": "⅖", "3/5": "⅗", "4/5": "⅘",
            "1/6": "⅙", "5/6": "⅚", "1/7": "⅐",
            "1/8": "⅛", "3/8": "⅜", "5/8": "⅝", "7/8": "⅞",
            "1/9": "⅑", "1/10": "⅒"
        ]
        
        let key = "\(num)/\(denom)"
        if let unicode = commonFractions[key] {
            return unicode
        }
        
        // For others, use superscript/subscript
        let superscripts = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
                           "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
        let subscripts = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
                         "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
        
        var result = ""
        for char in num {
            result += superscripts[String(char)] ?? String(char)
        }
        result += "⁄" // fraction slash
        for char in denom {
            result += subscripts[String(char)] ?? String(char)
        }
        return result
    }
}

// MARK: - Section Card View (Innovative Display)

private struct SectionCardView: View {
    let type: SectionCardType
    let content: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.caption.bold())
                    .foregroundStyle(type.color)
                Text(type.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(type.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(type.color.opacity(0.15))
            .clipShape(Capsule())
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(content.enumerated()), id: \.offset) { _, line in
                    renderContentLine(line)
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    @ViewBuilder
    private func renderContentLine(_ line: String) -> some View {
        if line.contains("→") || line.contains("↔") {
            // Mapping line
            let parts = line.replacingOccurrences(of: "↔", with: "→").components(separatedBy: "→")
            if parts.count == 2 {
                HStack(alignment: .top, spacing: 8) {
                    Text(parseInline(cleanBullet(parts[0])))
                        .font(.subheadline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(parseInline(parts[1].trimmingCharacters(in: .whitespaces)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(parseInline(line))
            }
        } else if line.hasPrefix("•") || line.hasPrefix("-") {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(type.color)
                    .frame(width: 5, height: 5)
                    .padding(.top, 6)
                Text(parseInline(cleanBullet(line)))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(parseInline(line))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func cleanBullet(_ text: String) -> String {
        text.replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text
        
        while !remaining.isEmpty {
            if let boldRange = remaining.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
                let before = String(remaining[..<boldRange.lowerBound])
                if !before.isEmpty { result.append(AttributedString(before)) }
                let boldContent = String(remaining[boldRange]).replacingOccurrences(of: "**", with: "")
                var boldAttr = AttributedString(boldContent)
                boldAttr.font = .subheadline.bold()
                result.append(boldAttr)
                remaining = String(remaining[boldRange.upperBound...])
            } else {
                result.append(AttributedString(remaining))
                break
            }
        }
        return result
    }
}

// MARK: - Mapping List View

private struct MappingListView: View {
    let items: [(left: String, right: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    Text(parseInline(cleanText(item.left)))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    
                    Text(parseInline(cleanText(item.right)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func cleanText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }
    
    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text
        
        while !remaining.isEmpty {
            if let boldRange = remaining.range(of: "\\*\\*(.+?)\\*\\*", options: .regularExpression) {
                let before = String(remaining[..<boldRange.lowerBound])
                if !before.isEmpty { result.append(AttributedString(before)) }
                let boldContent = String(remaining[boldRange]).replacingOccurrences(of: "**", with: "")
                var boldAttr = AttributedString(boldContent)
                boldAttr.font = .subheadline.bold()
                result.append(boldAttr)
                remaining = String(remaining[boldRange.upperBound...])
            } else {
                result.append(AttributedString(remaining))
                break
            }
        }
        return result
    }
}

// MARK: - Comparison Table View

private struct ComparisonTableView: View {
    let headers: [String]
    let rows: [[String]]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    Text(cleanText(header))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color.accentColor)
                        .frame(minHeight: 48)
                    
                    if index < headers.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 1)
                    }
                }
            }
            
            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                    
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            Text(cleanText(cell))
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .background(rowIndex % 2 == 0 ? Color(.systemBackground) : Color(.secondarySystemGroupedBackground))
                            
                            if colIndex < row.count - 1 {
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(width: 0.5)
                                    .background(rowIndex % 2 == 0 ? Color(.systemBackground) : Color(.secondarySystemGroupedBackground))
                            }
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
    
    private func cleanText(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var animatingDot = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(.tertiaryLabel))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animatingDot == index ? 1.2 : 0.8)
                        .opacity(animatingDot == index ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onAppear {
                startAnimation()
            }
            
            Spacer(minLength: 60)
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }
}

// MARK: - Quick Prompts Bar

private struct QuickPromptsBar: View {
    let prompts: [QuickPrompt]
    let onSelect: (QuickPrompt) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts) { prompt in
                    Button {
                        onSelect(prompt)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: prompt.icon)
                                .font(.caption)
                            Text(prompt.label)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Chat Input Bar

private struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onTextChange: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about this material...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($isFocused)
                .lineLimit(1...5)
                .onChange(of: text) { _, newValue in
                    onTextChange(newValue)
                }
                .onSubmit {
                    if !text.isEmpty && !isLoading {
                        onSend()
                    }
                }
            
            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                            ? Color(.tertiaryLabel)
                            : Color.accentColor
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Flashcard Preview Sheet

private struct FlashcardPreviewSheet: View {
    let flashcards: [(front: String, back: String)]
    let studySet: StudySet
    let onConfirm: ([(front: String, back: String)]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedIndices: Set<Int> = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header illustration
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    Text("Create Flashcards")
                        .font(.title2.bold())
                    
                    Text("Select which cards to add to **\(studySet.title)**")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                .padding(.horizontal, 32)
                
                // Flashcard list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(flashcards.enumerated()), id: \.offset) { index, card in
                            FlashcardPreviewCard(
                                front: card.front,
                                back: card.back,
                                isSelected: selectedIndices.contains(index),
                                onToggle: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedIndices.contains(index) {
                                            selectedIndices.remove(index)
                                        } else {
                                            selectedIndices.insert(index)
                                        }
                                    }
                                    HapticsManager.shared.lightImpact()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    // Select all / deselect all
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedIndices.count == flashcards.count {
                                    selectedIndices.removeAll()
                                } else {
                                    selectedIndices = Set(flashcards.indices)
                                }
                            }
                            HapticsManager.shared.lightImpact()
                        } label: {
                            Text(selectedIndices.count == flashcards.count ? "Deselect All" : "Select All")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                        
                        Spacer()
                        
                        Text("\(selectedIndices.count) of \(flashcards.count) selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        Button {
                            let selected = selectedIndices.sorted().map { flashcards[$0] }
                            onConfirm(selected)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add \(selectedIndices.count) Cards")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedIndices.isEmpty ? Color.accentColor.opacity(0.5) : Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(selectedIndices.isEmpty)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                selectedIndices = Set(flashcards.indices)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct FlashcardPreviewCard: View {
    let front: String
    let back: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Front side
                HStack {
                    Text("Q")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Text(front)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                
                // Divider
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                
                // Back side
                HStack(alignment: .top) {
                    Text("A")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Text(back)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct FlashcardPreviewRow: View {
    let front: String
    let back: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(front)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    Text(back)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                    .font(.title2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: StudySet.self, Flashcard.self, Question.self, ChatMessage.self,
        configurations: config
    )
    
    let studySet = StudySet(
        title: "Sample Study Set",
        originalText: "This is sample study content about photosynthesis. Photosynthesis is the process by which plants convert sunlight into energy.",
        summary: "Plants use photosynthesis to convert sunlight into energy."
    )
    container.mainContext.insert(studySet)
    
    return NavigationStack {
        StudyChatView(studySet: studySet)
            .modelContainer(container)
    }
}
