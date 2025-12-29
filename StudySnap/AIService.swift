import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AIError: Error {
    case generationFailed
    case invalidResponse
    case parsingFailed
    case apiError(String)
}

actor AIService {
    static let shared = AIService()

    private enum Provider {
        case appleIntelligence
        case openRouter
    }

    private struct ProviderSelection {
        let provider: Provider
        let fallbackNotice: String?
    }

    private var fallbackNotice: String?
    
    // Helper structs for JSON parsing
    private struct QuestionResponse: Codable, Sendable {
        let question: String
        let answer: String
        let options: [String]
        let explanation: String?
    }

    private struct FlashcardResponse: Codable, Sendable {
        let front: String
        let back: String
    }

    // OpenRouter API Structs
    private struct OpenRouterRequest: Codable, Sendable {
        let model: String
        let messages: [Message]
        
        struct Message: Codable, Sendable {
            let role: String
            let content: String
        }
    }

    private struct OpenRouterResponse: Codable, Sendable {
        let choices: [Choice]
        
        struct Choice: Codable, Sendable {
            let message: Message
        }
        
        struct Message: Codable, Sendable {
            let content: String
        }
    }
    
    private let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    
    private init() {}

    // Small randomised delay to reduce rate-limiting (0.5 - 1.0 seconds)
    private func applyRateLimitDelay() async {
        let millis = UInt64(Int.random(in: 500...1000))
        do {
            try await Task.sleep(nanoseconds: millis * 1_000_000)
        } catch {
            // Ignored: if the task is cancelled, proceed without delay
        }
    }
    
    private func performRequest(systemPrompt: String, userPrompt: String) async throws -> String {
        let selection = await selectProvider()

        switch selection.provider {
        case .appleIntelligence:
            do {
                return try await runAppleIntelligence(systemPrompt: systemPrompt, userPrompt: userPrompt)
            } catch {
                let reason = "Apple Intelligence unavailable (\(error.localizedDescription)). Falling back to OpenRouter (BYOK)."
                setFallbackNoticeIfNeeded(selection.fallbackNotice ?? reason)
                return try await runOpenRouter(systemPrompt: systemPrompt, userPrompt: userPrompt)
            }
        case .openRouter:
            setFallbackNoticeIfNeeded(selection.fallbackNotice)
            return try await runOpenRouter(systemPrompt: systemPrompt, userPrompt: userPrompt)
        }
    }

    private func runOpenRouter(systemPrompt: String, userPrompt: String) async throws -> String {
        let apiKey = try await openRouterApiKey()
        let model = await ModelSettings.openRouterModel()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("StudySnap", forHTTPHeaderField: "X-Title")

        let payload = OpenRouterRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)

        await applyRateLimitDelay()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.generationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("OpenRouter API Error: \(errorText)")
            }
            throw AIError.apiError("Status code: \(httpResponse.statusCode)")
        }

        let decodedResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let content = decodedResponse.choices.first?.message.content else {
            throw AIError.invalidResponse
        }

        print("AI (OpenRouter) response:\n\(content)\n--- end response ---")

        return content
    }

    private func runAppleIntelligence(systemPrompt: String, userPrompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: systemPrompt)
            let response = try await session.respond(to: userPrompt)
            print("AI (Apple Intelligence) response:\n\(response.content)\n--- end response ---")
            return response.content
        } else {
            throw AIError.apiError("Apple Intelligence requires iOS 26 or later.")
        }
        #else
        throw AIError.apiError("FoundationModels framework is unavailable in this SDK.")
        #endif
    }

    private func selectProvider() async -> ProviderSelection {
        let preference = await ModelSettings.preference()

        switch preference {
        case .openRouterOnly:
            return ProviderSelection(provider: .openRouter, fallbackNotice: nil)
        case .automatic:
            if Self.appleIntelligenceAvailable {
                return ProviderSelection(provider: .appleIntelligence, fallbackNotice: nil)
            }
            let notice = "Apple Intelligence requires iOS 26+ with supported hardware and enabled in Settings. Falling back to OpenRouter (BYOK)."
            return ProviderSelection(provider: .openRouter, fallbackNotice: notice)
        }
    }

    private func openRouterApiKey() async throws -> String {
        let key = await ModelSettings.openRouterApiKey()
        guard key.isEmpty == false else {
            throw AIError.apiError("Missing OpenRouter API key. Add it in Model Settings.")
        }
        return key
    }

    private func setFallbackNoticeIfNeeded(_ notice: String?) {
        guard fallbackNotice == nil else { return }
        guard let notice = notice else { return }
        fallbackNotice = notice
    }

    func popFallbackNotice() -> String? {
        let note = fallbackNotice
        fallbackNotice = nil
        return note
    }

    func clearFallbackNotice() {
        fallbackNotice = nil
    }

    func previewFallbackNoticeForCurrentPreference() async -> String? {
        let selection = await selectProvider()
        return selection.fallbackNotice
    }

    nonisolated static var appleIntelligenceAvailable: Bool {
        ModelSettings.appleIntelligenceAvailable
    }
    
    enum SummaryStyle: String, CaseIterable, Identifiable {
        case paragraph = "Paragraph"
        case bulletPoints = "Bullet Points"
        
        var id: String { self.rawValue }
    }
    
    enum SummaryDifficulty: String, CaseIterable, Identifiable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var id: String { self.rawValue }
    }
    
    private func cleanJSON(_ jsonString: String) -> String {
        // Deprecated: No longer used with custom text format parsing
        return jsonString
    }

    private func normalizeWhitespace(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeTags(_ text: String) -> String {
        let tags = ["[QUESTION]", "[ANSWER]", "[OPTION]", "[EXPLANATION]", "[FRONT]", "[BACK]", "[TITLE]", "[DESCRIPTION]", "[CATEGORY]", "[DIFFICULTY]", "[TIME]", "[ICON]", "[END]"]
        let closing = ["[/QUESTION]", "[/ANSWER]", "[/OPTION]", "[/EXPLANATION]", "[/FRONT]", "[/BACK]", "[/TITLE]", "[/DESCRIPTION]", "[/CATEGORY]", "[/DIFFICULTY]", "[/TIME]", "[/ICON]", "[/END]"]

        var result = text
        for tag in tags {
            result = result.replacingOccurrences(of: tag, with: "\n\(tag)\n")
        }
        for close in closing {
            result = result.replacingOccurrences(of: close, with: "\n")
        }
        return result
    }

    private func cleanMath(_ text: String) -> String {
        var result = text
        // Replace \[ ... \] with $$ ... $$
        result = result.replacingOccurrences(of: "\\[", with: "$$")
        result = result.replacingOccurrences(of: "\\]", with: "$$")
        // Replace \( ... \) with $ ... $
        result = result.replacingOccurrences(of: "\\(", with: "$")
        result = result.replacingOccurrences(of: "\\)", with: "$")
        return result
    }

    private func removeAngleBracketPlaceholders(_ text: String) -> String {
        // Remove angle bracket placeholders like <Question text>, <Correct answer text>, etc.
        // Pattern: < followed by any text ending in >
        var result = text
        result = result.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optionsContainAnswer(_ options: [String], answer: String) -> Bool {
        let normAnswer = normalizeWhitespace(answer)
        return options.contains { normalizeWhitespace($0) == normAnswer }
    }

    // Produces a clear annotation used in fallback/mock responses so the UI can
    // show that the content is not live AI output, include an error code, and
    // instruct the user to retry.
    private func fallbackAnnotation(for error: Error) -> String {
        let code: String
        if case AIError.apiError(let msg) = error {
            code = msg
        } else {
            let ns = error as NSError
            code = "\(ns.domain) \(ns.code)"
        }

        return "*** ERROR — AI Unavailable: Showing MOCK DATA. Error: \(code). Please retry. ***"
    }
    
    func generateSummary(from text: String, style: SummaryStyle = .paragraph, wordCount: Int = 150, difficulty: SummaryDifficulty = .intermediate) async throws -> String {
        do {
            let systemPrompt = "You are a concise study assistant. Produce clean, well-formatted output that follows instructions exactly. Do not add headings, labels, bullets, or extra commentary."
            let styleInstruction: String
            if style == .bulletPoints {
                styleInstruction = "FORMAT AS BULLETS ONLY. Each bullet must be its own line and start with '- ' exactly. No numbering. No paragraph text. Do NOT break bullets across multiple lines. Example exactly:\n- Key idea one\n- Key idea two\n- Key idea three"
            } else {
                styleInstruction = "FORMAT AS ONE SINGLE PARAGRAPH (4-7 sentences). ABSOLUTELY NO BULLET POINTS. NO LISTS. NO HEADINGS. NO EXTRA SECTIONS. Just one continuous block of text."
            }
            let difficultyInstruction: String
            switch difficulty {
            case .beginner:
                difficultyInstruction = "Use simple language suitable for a beginner. Avoid jargon where possible."
            case .intermediate:
                difficultyInstruction = "Use standard language suitable for an intermediate learner."
            case .advanced:
                difficultyInstruction = "Use advanced, academic language suitable for an expert."
            }
            
            let userPrompt = """
            Summarise the following text. Follow formatting instructions EXACTLY. Do NOT add headings or labels. Keep it tight and avoid filler.
            \(styleInstruction)
            Target length: aim for \(max(80, wordCount - 30))-\(wordCount + 30) words (soft target, stay concise).
            Difficulty level: \(difficulty.rawValue) (\(difficultyInstruction)).
            
            MATH FORMATTING RULES (follow exactly):
            - Wrap ALL math expressions in single dollar signs: $...$
            - Use \\frac{a}{b} for fractions, NOT a/b for complex fractions
            - Use \\sqrt{x} or \\sqrt[n]{x} for roots
            - Use \\sum_{i=1}^{n}, \\int_{a}^{b}, \\prod for summation, integrals, products
            - Use ^{} for superscripts and _{} for subscripts (e.g., $x^{2}$, $a_{n}$)
            - Use \\left( and \\right) for auto-sizing parentheses
            - Use \\cdot for multiplication, \\times for cross product
            - Greek letters: \\alpha, \\beta, \\pi, \\theta, \\Delta, etc.
            - Examples: $\\frac{-b \\pm \\sqrt{b^{2} - 4ac}}{2a}$, $\\int_{0}^{\\infty} e^{-x^{2}} dx$
            
            Text:
            \(text)
            """
            
            return try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        } catch {
            print("AI Generation failed: \(error). Falling back to mock.")
            // Fallback to mock if generation fails
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            let note = fallbackAnnotation(for: error)
            return """
            *** ERROR — MOCK DATA ***
            AI request failed: \(String(describing: error))
            \(note)

            This is a concise summary of the provided text. The text discusses the importance of study habits and how using AI can enhance learning efficiency. It covers key topics such as active recall, spaced repetition, and the benefits of summarising information.
            """
        }
    }
    
    func generateQuestions(from text: String, count: Int) async throws -> [(question: String, answer: String, options: [String], explanation: String?)] {
        do {
            let systemPrompt = "You are a precise quiz generator. Output ONLY the requested format. No conversational text."
            let userPrompt = """
            Generate \(count) multiple choice study questions based on the text below.
            
            STRICT OUTPUT FORMAT (Tag-based):
            
            [QUESTION]
            Question text
            [ANSWER]
            Correct answer text
            [OPTION]
            Correct answer text
            [OPTION]
            Distractor 1
            [OPTION]
            Distractor 2
            [OPTION]
            Distractor 3
            [EXPLANATION]
            Explanation
            [END]
            
            RULES:
            1. Use [QUESTION], [ANSWER], [OPTION], [EXPLANATION], [END] tags exactly as shown.
            2. Put content on the lines following the tags. Do NOT wrap content in < > brackets.
            3. Provide exactly 4 [OPTION] tags. One MUST match [ANSWER] exactly.
            4. MATH: Use LaTeX with single dollar signs ($...$) for ALL math.
               - CORRECT: $x^2 + 2x$
               - WRONG: \\[ x^2 + 2x \\]
               - WRONG: [ x^2 + 2x ]
               - WRONG: \\( x^2 + 2x \\)
            5. Do not use markdown code blocks (```).
            6. Ensure there are exactly 4 options for every question.
            
            Text:
            \(text)
            """
            
            let rawContent = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            let content = normalizeTags(rawContent)
            
            var questions: [(String, String, [String], String?)] = []
            let blocks = content.components(separatedBy: "[END]")
            
            for block in blocks {
                let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedBlock.isEmpty else { continue }
                
                var question = ""
                var answer = ""
                var options: [String] = []
                var explanation: String? = nil
                
                let lines = trimmedBlock.components(separatedBy: .newlines)
                var currentTag = ""
                var currentText = ""
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine == "[QUESTION]" || trimmedLine == "[ANSWER]" || trimmedLine == "[OPTION]" || trimmedLine == "[EXPLANATION]" {
                        
                        // Save previous tag content
                        if !currentTag.isEmpty {
                            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !value.isEmpty {
                                switch currentTag {
                                case "[QUESTION]": question = removeAngleBracketPlaceholders(cleanMath(value))
                                case "[ANSWER]": answer = removeAngleBracketPlaceholders(cleanMath(value))
                                case "[OPTION]": options.append(removeAngleBracketPlaceholders(cleanMath(value)))
                                case "[EXPLANATION]": explanation = removeAngleBracketPlaceholders(cleanMath(value))
                                default: break
                                }
                            }
                        }
                        
                        currentTag = trimmedLine
                        currentText = ""
                    } else {
                        currentText += line + "\n"
                    }
                }
                
                // Save last tag content
                if !currentTag.isEmpty {
                    let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        switch currentTag {
                        case "[QUESTION]": question = removeAngleBracketPlaceholders(cleanMath(value))
                        case "[ANSWER]": answer = removeAngleBracketPlaceholders(cleanMath(value))
                        case "[OPTION]": options.append(removeAngleBracketPlaceholders(cleanMath(value)))
                        case "[EXPLANATION]": explanation = removeAngleBracketPlaceholders(cleanMath(value))
                        default: break
                        }
                    }
                }
                
                if !question.isEmpty && !answer.isEmpty {
                    // Fix options if needed
                    if !optionsContainAnswer(options, answer: answer) {
                        // Insert answer at the beginning instead of overwriting
                        options.insert(answer, at: 0)
                    }
                    
                    // Ensure 4 options
                    while options.count < 4 {
                        options.append("Option \(options.count + 1)")
                    }
                    if options.count > 4 {
                        options = Array(options.prefix(4))
                    }
                    
                    questions.append((question, answer, options.shuffled(), explanation))
                }
            }
            
            if questions.isEmpty { throw AIError.parsingFailed }
            return questions
            
        } catch {
            print("AI Generation failed: \(error). Falling back to mock.")

            // Mock Fallback
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

            var questions: [(String, String, [String], String?)] = []
            let note = fallbackAnnotation(for: error)
            for i in 1...count {
                let correctAnswer = "The correct answer for question \(i)"
                let distractors = ["Distractor 1", "Distractor 2", "Distractor 3"]
                let options = (distractors + [correctAnswer]).shuffled()
                let explanation = "This is the explanation for question \(i). It explains why the answer is correct.\n\n\(note)"
                let questionText = "[MOCK DATA] \(note)\n\nWhat is the key concept in section \(i)?"

                questions.append((questionText, correctAnswer, options, explanation))
            }
            return questions
        }
    }
    
    func generateFlashcards(from text: String, count: Int) async throws -> [(front: String, back: String)] {
        do {
            let systemPrompt = "You are a precise flashcard generator. Follow the exact tag format. No markdown, no numbering, no extra prose. Front and back must be plain text (no TeX/LaTeX)."
            let userPrompt = """
            Generate \(count) flashcards (like in Quizlet) based on the following text.

            Use the following EXACT format for each flashcard (no extra blank lines between tags):

            [FRONT]
            Term text
            [BACK]
            Definition text
            [END]

            IMPORTANT - FOLLOW ALL:
            1) Do NOT use JSON or markdown.
            2) Do NOT use headings (#, ##) or bold/italics. No numbering of cards.
            3) Do NOT include TeX/LaTeX math in FRONT or BACK. Use plain text only.
            4) Keep the 'front' very short (3-9 words) and the 'back' concise (under 20 words).
            5) Keep EXACT tags as shown. No extra tags or bullets.
            6) Produce exactly \(count) flashcards.

            GOOD EXAMPLE (copy structure, change content):
            [FRONT]
            Factorising purpose
            [BACK]
            Reveal common factors to simplify.
            [END]
            
            MATH FORMATTING RULES (follow exactly):
            - Wrap ALL math expressions in single dollar signs: $...$
            - Use \\frac{a}{b} for fractions, NOT a/b for complex fractions
            - Use \\sqrt{x} or \\sqrt[n]{x} for roots
            - Use \\sum_{i=1}^{n}, \\int_{a}^{b}, \\prod for summation, integrals, products
            - Use ^{} for superscripts and _{} for subscripts (e.g., $x^{2}$, $a_{n}$)
            - Use \\left( and \\right) for auto-sizing parentheses
            - Use \\cdot for multiplication, \\times for cross product
            - Greek letters: \\alpha, \\beta, \\pi, \\theta, \\Delta, etc.
            - Examples: $\\frac{-b \\pm \\sqrt{b^{2} - 4ac}}{2a}$, $\\int_{0}^{\\infty} e^{-x^{2}} dx$
            
            Text:
            \(text)
            """
            
            let rawContent = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            let content = normalizeTags(rawContent)
            
            var cards: [(String, String)] = []
            let blocks = content.components(separatedBy: "[END]")
            
            for block in blocks {
                let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedBlock.isEmpty else { continue }
                
                var front = ""
                var back = ""
                
                let lines = trimmedBlock.components(separatedBy: .newlines)
                var currentTag = ""
                var currentText = ""
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine == "[FRONT]" || trimmedLine == "[BACK]" {
                        
                        // Save previous tag content
                        if !currentTag.isEmpty {
                            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !value.isEmpty {
                                switch currentTag {
                                case "[FRONT]": front = value
                                case "[BACK]": back = value
                                default: break
                                }
                                // If we've gathered both front and back within the same block,
                                // append the card immediately so multiple pairs in one block
                                // (when AI omitted [END] separators) are preserved.
                                if !front.isEmpty && !back.isEmpty {
                                    cards.append((front, back))
                                    front = ""
                                    back = ""
                                }
                            }
                        }
                        
                        currentTag = trimmedLine
                        currentText = ""
                    } else {
                        currentText += line + "\n"
                    }
                }
                
                // Save last tag content
                if !currentTag.isEmpty {
                    let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        switch currentTag {
                        case "[FRONT]": front = value
                        case "[BACK]": back = value
                        default: break
                        }
                    }
                }
                
                if !front.isEmpty && !back.isEmpty {
                    cards.append((front, back))
                }
            }
            
            if cards.isEmpty { throw AIError.parsingFailed }
            return cards
            
        } catch {
            print("AI Generation failed: \(error). Falling back to mock.")

            // Mock Fallback
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

            var cards: [(String, String)] = []
            let note = fallbackAnnotation(for: error)
            for i in 1...count {
                cards.append(("Term \(i)", "Definition for term \(i) derived from the text.\n\n\(note)"))
            }
            return cards
        }
    }
    
    // MARK: - Topic-Based Generation (Learn a new topic)
    
    /// Generates a learning guide/tutorial for a topic the user wants to learn
    func generateTopicGuide(topic: String, style: SummaryStyle = .paragraph, wordCount: Int = 300, difficulty: SummaryDifficulty = .intermediate) async throws -> String {
        do {
            let systemPrompt = "You are a concise study assistant. Produce clean, well-formatted output that follows instructions exactly. Do not add headings, labels, bullets, or extra commentary."
            let styleInstruction: String
            if style == .bulletPoints {
                styleInstruction = "FORMAT AS BULLETS ONLY. Each bullet must be its own line and start with '- ' exactly. No numbering. No paragraph text. Do NOT break bullets across multiple lines. Example exactly:\n- Key idea one\n- Key idea two\n- Key idea three"
            } else {
                styleInstruction = "FORMAT AS PROSE (PARAGRAPHS). Use standard paragraphs to structure the content. ABSOLUTELY NO BULLET POINTS. NO LISTS. Write in full sentences."
            }
            let difficultyInstruction: String
            switch difficulty {
            case .beginner:
                difficultyInstruction = "Use simple language suitable for a beginner. Avoid jargon where possible. Explain like the user is 5."
            case .intermediate:
                difficultyInstruction = "Use standard language suitable for an intermediate learner."
            case .advanced:
                difficultyInstruction = "Use advanced, academic language suitable for an expert."
            }
            
            let userPrompt = """
            Create a comprehensive learning guide about: \(topic)
            Follow formatting instructions EXACTLY. Do NOT add headings or labels. Keep it tight and avoid filler.
            \(styleInstruction)
            Target length: aim for \(max(80, wordCount - 30))-\(wordCount + 30) words (soft target, stay concise).
            Difficulty level: \(difficulty.rawValue) (\(difficultyInstruction)).
            
            Structure your guide to include these sections in order (use plain text paragraphs; do not use bullet points):
            1. A brief introduction to the topic
            2. Key concepts and fundamentals
            3. Step-by-step instructions or explanations (if applicable)
            4. Common mistakes to avoid or tips for success
            5. How to practice or apply this knowledge
            
            MATH FORMATTING RULES (follow exactly):
            - Wrap ALL math expressions in single dollar signs: $...$
            - Use \\frac{a}{b} for fractions, NOT a/b for complex fractions
            - Use \\sqrt{x} or \\sqrt[n]{x} for roots
            - Use \\sum_{i=1}^{n}, \\int_{a}^{b}, \\prod for summation, integrals, products
            - Use ^{} for superscripts and _{} for subscripts (e.g., $x^{2}$, $a_{n}$)
            - Use \\left( and \\right) for auto-sizing parentheses
            - Use \\cdot for multiplication, \\times for cross product
            - Greek letters: \\alpha, \\beta, \\pi, \\theta, \\Delta, etc.
            - Examples: $\\frac{-b \\pm \\sqrt{b^{2} - 4ac}}{2a}$, $\\int_{0}^{\\infty} e^{-x^{2}} dx$
            """
            
            return try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        } catch {
            print("AI Generation failed: \(error). Falling back to mock.")
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            let note = fallbackAnnotation(for: error)
            return """
            *** ERROR — MOCK DATA ***
            AI request failed: \(String(describing: error))
            \(note)

            # Learning Guide: \(topic)

            This is a comprehensive guide to help you learn about \(topic). The guide covers fundamental concepts, practical applications, and tips for mastery.
            """
        }
    }
    
    /// Generates quiz questions about a topic for learning purposes
    func generateTopicQuestions(topic: String, count: Int, difficulty: SummaryDifficulty = .intermediate) async throws -> [(question: String, answer: String, options: [String], explanation: String?)] {
        do {
            let systemPrompt = "You are a precise quiz generator. Output ONLY the requested format. No conversational text."
            let difficultyInstruction: String
            switch difficulty {
            case .beginner:
                difficultyInstruction = "Create basic questions testing fundamental understanding."
            case .intermediate:
                difficultyInstruction = "Create moderately challenging questions testing practical application."
            case .advanced:
                difficultyInstruction = "Create challenging questions testing deep understanding and edge cases."
            }
            
            let userPrompt = """
            Generate \(count) multiple choice study questions about: \(topic)
            
            Difficulty: \(difficulty.rawValue) - \(difficultyInstruction)
            
            STRICT OUTPUT FORMAT (Tag-based):
            
            [QUESTION]
            Question text
            [ANSWER]
            Correct answer text
            [OPTION]
            Correct answer text
            [OPTION]
            Distractor 1
            [OPTION]
            Distractor 2
            [OPTION]
            Distractor 3
            [EXPLANATION]
            Explanation
            [END]
            
            RULES:
            1. Use [QUESTION], [ANSWER], [OPTION], [EXPLANATION], [END] tags exactly as shown.
            2. Put content on the lines following the tags. Do NOT wrap content in < > brackets.
            3. Provide exactly 4 [OPTION] tags. One MUST match [ANSWER] exactly.
            4. MATH: Use LaTeX with single dollar signs ($...$) for ALL math.
               - CORRECT: $x^2 + 2x$
               - WRONG: \\[ x^2 + 2x \\]
               - WRONG: [ x^2 + 2x ]
               - WRONG: \\( x^2 + 2x \\)
            5. Do not use markdown code blocks (```).
            6. Ensure there are exactly 4 options for every question.
            """
            
            let rawContent = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            let content = normalizeTags(rawContent)
            
            var questions: [(String, String, [String], String?)] = []
            let blocks = content.components(separatedBy: "[END]")
            
            for block in blocks {
                let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedBlock.isEmpty else { continue }
                
                var question = ""
                var answer = ""
                var options: [String] = []
                var explanation: String? = nil
                
                let lines = trimmedBlock.components(separatedBy: .newlines)
                var currentTag = ""
                var currentText = ""
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine == "[QUESTION]" || trimmedLine == "[ANSWER]" || trimmedLine == "[OPTION]" || trimmedLine == "[EXPLANATION]" {
                        if !currentTag.isEmpty {
                            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !value.isEmpty {
                                switch currentTag {
                                case "[QUESTION]": question = removeAngleBracketPlaceholders(cleanMath(value))
                                case "[ANSWER]": answer = removeAngleBracketPlaceholders(cleanMath(value))
                                case "[OPTION]": options.append(removeAngleBracketPlaceholders(cleanMath(value)))
                                case "[EXPLANATION]": explanation = removeAngleBracketPlaceholders(cleanMath(value))
                                default: break
                                }
                            }
                        }
                        currentTag = trimmedLine
                        currentText = ""
                    } else {
                        currentText += line + "\n"
                    }
                }
                
                if !currentTag.isEmpty {
                    let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        switch currentTag {
                        case "[QUESTION]": question = removeAngleBracketPlaceholders(cleanMath(value))
                        case "[ANSWER]": answer = removeAngleBracketPlaceholders(cleanMath(value))
                        case "[OPTION]": options.append(removeAngleBracketPlaceholders(cleanMath(value)))
                        case "[EXPLANATION]": explanation = removeAngleBracketPlaceholders(cleanMath(value))
                        default: break
                        }
                    }
                }
                
                if !question.isEmpty && !answer.isEmpty {
                    // Fix options if needed
                    if !optionsContainAnswer(options, answer: answer) {
                        // Insert answer at the beginning instead of overwriting
                        options.insert(answer, at: 0)
                    }
                    
                    // Ensure 4 options
                    while options.count < 4 {
                        options.append("Option \(options.count + 1)")
                    }
                    if options.count > 4 {
                        options = Array(options.prefix(4))
                    }
                    
                    questions.append((question, answer, options.shuffled(), explanation))
                }
            }
            
            if questions.isEmpty { throw AIError.parsingFailed }
            return questions
            
        } catch {
            print("AI Generation failed: \(error). Falling back to mock.")
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

            var questions: [(String, String, [String], String?)] = []
            let note = fallbackAnnotation(for: error)
            for i in 1...count {
                let correctAnswer = "Correct answer about \(topic) - concept \(i)"
                let distractors = ["Incorrect option A", "Incorrect option B", "Incorrect option C"]
                let options = (distractors + [correctAnswer]).shuffled()
                let explanation = "This is the explanation for question \(i) about \(topic).\n\n\(note)"
                let questionText = "[MOCK DATA] \(note)\n\nQuestion \(i) about \(topic)?"
                questions.append((questionText, correctAnswer, options, explanation))
            }
            return questions
        }
    }
    
    /// Generates flashcards to help learn a new topic
    func generateTopicFlashcards(topic: String, count: Int, difficulty: SummaryDifficulty = .intermediate) async throws -> [(front: String, back: String)] {
        do {
            let systemPrompt = "You are a precise flashcard generator. Follow the exact tag format. No markdown, no numbering, no extra prose. Front and back must be plain text (no TeX/LaTeX)."
            let difficultyInstruction: String
            switch difficulty {
            case .beginner:
                difficultyInstruction = "Focus on basic terminology and fundamental concepts."
            case .intermediate:
                difficultyInstruction = "Include practical applications and important techniques."
            case .advanced:
                difficultyInstruction = "Cover advanced concepts, nuances, and expert-level knowledge."
            }
            
            let userPrompt = """
            Generate \(count) flashcards (like in Quizlet) about: \(topic)
            
            Difficulty: \(difficulty.rawValue) - \(difficultyInstruction)

            Use the following EXACT format for each flashcard (no extra blank lines between tags):

            [FRONT]
            Term text
            [BACK]
            Definition text
            [END]

            IMPORTANT - FOLLOW ALL:
            1) Do NOT use JSON or markdown.
            2) Do NOT use headings (#, ##) or bold/italics. No numbering of cards.
            3) Do NOT include TeX/LaTeX math in FRONT or BACK. Use plain text only.
            4) Keep the 'front' very short (3-9 words) and the 'back' concise (under 20 words).
            5) Keep EXACT tags as shown. No extra tags or bullets.
            6) Produce exactly \(count) flashcards.

            GOOD EXAMPLE (copy structure, change content):
            [FRONT]
            Factorising purpose
            [BACK]
            Reveal common factors to simplify.
            [END]
            
            MATH FORMATTING RULES (follow exactly):
            - Wrap ALL math expressions in single dollar signs: $...$
            - Use \\frac{a}{b} for fractions, NOT a/b for complex fractions
            - Use \\sqrt{x} or \\sqrt[n]{x} for roots
            - Use \\sum_{i=1}^{n}, \\int_{a}^{b}, \\prod for summation, integrals, products
            - Use ^{} for superscripts and _{} for subscripts (e.g., $x^{2}$, $a_{n}$)
            - Use \\left( and \\right) for auto-sizing parentheses
            - Use \\cdot for multiplication, \\times for cross product
            - Greek letters: \\alpha, \\beta, \\pi, \\theta, \\Delta, etc.
            - Examples: $\\frac{-b \\pm \\sqrt{b^{2} - 4ac}}{2a}$, $\\int_{0}^{\\infty} e^{-x^{2}} dx$
            """
            
            let rawContent = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            let content = normalizeTags(rawContent)
            
            var cards: [(String, String)] = []
            let blocks = content.components(separatedBy: "[END]")
            
            for block in blocks {
                let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedBlock.isEmpty else { continue }
                
                var front = ""
                var back = ""
                
                let lines = trimmedBlock.components(separatedBy: .newlines)
                var currentTag = ""
                var currentText = ""
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine == "[FRONT]" || trimmedLine == "[BACK]" {
                        if !currentTag.isEmpty {
                            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !value.isEmpty {
                                switch currentTag {
                                case "[FRONT]": front = value
                                case "[BACK]": back = value
                                default: break
                                }
                                // Handle multiple front/back pairs inside a single block
                                if !front.isEmpty && !back.isEmpty {
                                    cards.append((front, back))
                                    front = ""
                                    back = ""
                                }
                            }
                        }
                        currentTag = trimmedLine
                        currentText = ""
                    } else {
                        currentText += line + "\n"
                    }
                }
                
                if !currentTag.isEmpty {
                    let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        switch currentTag {
                        case "[FRONT]": front = value
                        case "[BACK]": back = value
                        default: break
                        }
                    }
                }
                
                if !front.isEmpty && !back.isEmpty {
                    cards.append((front, back))
                }
            }
            
            if cards.isEmpty { throw AIError.parsingFailed }
            return cards
            
        } catch {
            print("AI Generation failed: \(error). Falling back to mock.")
            try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

            var cards: [(String, String)] = []
            let note = fallbackAnnotation(for: error)
            for i in 1...count {
                cards.append(("Key concept \(i) of \(topic)", "Explanation of concept \(i) related to \(topic).\n\n\(note)"))
            }
            return cards
        }
    }
    
    // MARK: - Tutor Chat
    
    /// Describes what context to include in the tutor chat
    struct TutorContext: Sendable {
        let originalText: String
        let summary: String?
        let studySetTitle: String
        
        /// Creates context with only original text and summary (no flashcards/quiz)
        static func create(from studySet: StudySet) -> TutorContext {
            return TutorContext(
                originalText: studySet.originalText,
                summary: studySet.summary,
                studySetTitle: studySet.title
            )
        }
        
        /// Builds the context string for the AI prompt and logs what's included
        func buildContextString() -> String {
            var contextParts: [String] = []
            
            // Always include original text
            contextParts.append("originalText")
            
            var context = """
            STUDY MATERIAL:
            \(originalText)
            """
            
            if let summary = summary, !summary.isEmpty {
                contextParts.append("summary")
                context += """
                
                
                SUMMARY:
                \(summary)
                """
            }
            
            // Console log what context is being sent
            print("[StudySnap Tutor] Context sent to AI: [\(contextParts.joined(separator: ", "))] for study set: \(studySetTitle)")
            
            return context
        }
    }
    
    /// Chat message for conversational context
    struct ChatTurn: Sendable {
        let role: String // "user" or "assistant"
        let content: String
    }
    
    /// Typealias for backwards compatibility
    typealias TutorResponseFormat = TutorResponseFormatType
    
    /// Performs a chat request with conversation history and study set context
    func performChat(
        messages: [ChatTurn],
        context: TutorContext,
        format: TutorResponseFormat = .standard
    ) async throws -> String {
        // Build context string (this also logs what's included)
        let contextString = context.buildContextString()
        
        // Get format-specific output instructions
        let formatBlock = getFormatInstructions(for: format)
        
        // SYSTEM PROMPT: Role + rules only (no user content)
        let systemPrompt = """
        You are a concise study tutor. Follow these rules EXACTLY:
        
        CRITICAL RULES:
        1. Start with content immediately. NEVER say "Certainly", "Sure", "Here's", etc.
        2. MAXIMUM 100 words total. Be extremely concise.
        3. Use **bold** for key terms only.
        4. Use • for bullets, numbered lists (1. 2. 3.) for steps.
        5. For fractions use a/b. For exponents: x².
        6. Never echo instructions or study set name.
        
        TAG RULES (CRITICAL):
        - When format instructions specify a tag like [SIMPLE], [MNEMONIC], [COMPARE], etc., you MUST start your response with that EXACT tag in ALL CAPS inside square brackets.
        - Example: If format says use [SIMPLE], your response MUST begin with "[SIMPLE]" on its own line.
        - Tags must be ALL UPPERCASE: [SIMPLE] not [Simple], [MNEMONIC] not [Mnemonic]
        - Sub-tags like [BREAKDOWN], [TIP], [SUMMARY] must also be ALL CAPS.
        
        \(formatBlock)
        """
        
        // USER PROMPT: Context + actual question (sent as the user message)
        // We inject context into the first user message or prepend to current
        var augmentedMessages = messages
        if let lastUserIndex = messages.lastIndex(where: { $0.role == "user" }) {
            let originalContent = messages[lastUserIndex].content
            let augmentedContent = """
            [CONTEXT]
            \(contextString)
            [END CONTEXT]
            
            [QUESTION]
            \(originalContent)
            """
            augmentedMessages[lastUserIndex] = ChatTurn(role: "user", content: augmentedContent)
        }
        
        print("[StudySnap Tutor] Sending request with format: \(format)")
        
        return try await performConversationalRequest(
            systemPrompt: systemPrompt,
            messages: augmentedMessages
        )
    }
    
    /// Performs a conversational request with message history
    private func performConversationalRequest(
        systemPrompt: String,
        messages: [ChatTurn]
    ) async throws -> String {
        let selection = await selectProvider()
        
        switch selection.provider {
        case .appleIntelligence:
            do {
                return try await runAppleIntelligenceConversation(
                    systemPrompt: systemPrompt,
                    messages: messages
                )
            } catch {
                let reason = "Apple Intelligence unavailable. Falling back to OpenRouter."
                setFallbackNoticeIfNeeded(selection.fallbackNotice ?? reason)
                return try await runOpenRouterConversation(
                    systemPrompt: systemPrompt,
                    messages: messages
                )
            }
        case .openRouter:
            setFallbackNoticeIfNeeded(selection.fallbackNotice)
            return try await runOpenRouterConversation(
                systemPrompt: systemPrompt,
                messages: messages
            )
        }
    }
    
    private func runOpenRouterConversation(
        systemPrompt: String,
        messages: [ChatTurn]
    ) async throws -> String {
        let apiKey = try await openRouterApiKey()
        let model = await ModelSettings.openRouterModel()
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("StudySnap", forHTTPHeaderField: "X-Title")
        
        // Build messages array with system prompt and conversation history
        var apiMessages: [OpenRouterRequest.Message] = [
            .init(role: "system", content: systemPrompt)
        ]
        
        for msg in messages {
            apiMessages.append(.init(role: msg.role, content: msg.content))
        }
        
        let payload = OpenRouterRequest(model: model, messages: apiMessages)
        request.httpBody = try JSONEncoder().encode(payload)
        
        await applyRateLimitDelay()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.generationFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("OpenRouter API Error: \(errorText)")
            }
            throw AIError.apiError("Status code: \(httpResponse.statusCode)")
        }
        
        let decodedResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let content = decodedResponse.choices.first?.message.content else {
            throw AIError.invalidResponse
        }
        
        return content
    }
    
    private func runAppleIntelligenceConversation(
        systemPrompt: String,
        messages: [ChatTurn]
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: systemPrompt)
            
            // Only send the last user message to avoid echoing system prompts
            // The session already has the instructions (system prompt)
            if let lastMessage = messages.last, lastMessage.role == "user" {
                let response = try await session.respond(to: lastMessage.content)
                return response.content
            } else {
                throw AIError.invalidResponse
            }
        } else {
            throw AIError.apiError("Apple Intelligence requires iOS 26 or later.")
        }
        #else
        throw AIError.apiError("FoundationModels framework is unavailable.")
        #endif
    }
    
    // MARK: - Format Instructions for Specialized Responses
    
    private func getFormatInstructions(for format: TutorResponseFormat) -> String {
        switch format {
        case .standard:
            return """
            For general questions, respond in 2-4 sentences. Max 80 words.
            If you need to list points, start with [KEYPOINTS] tag.
            If explaining steps, start with [STEPS] tag.
            Otherwise, just answer directly without any tags.
            """
        case .comparison:
            return """
            YOU MUST START YOUR RESPONSE WITH: [COMPARE]
            
            EXACT FORMAT:
            [COMPARE]
            **[Topic A]** vs **[Topic B]**
            [KEYPOINTS]
            • **Similarity**: [What they share]
            • **Difference**: [How A differs] vs [How B differs]
            • **Difference**: [Another contrast]
            [SUMMARY]
            [One sentence: the key distinction.]
            
            All tags MUST be ALL CAPS. Max 80 words total.
            """
        case .mnemonic:
            return """
            YOU MUST START YOUR RESPONSE WITH: [MNEMONIC]
            
            EXACT FORMAT:
            [MNEMONIC]
            **[Catchy phrase or acronym]**
            [BREAKDOWN]
            • [Letter/Word] → [What it stands for]
            • [Letter/Word] → [What it stands for]
            [TIP]
            [One sentence on why this helps you remember.]
            
            All tags MUST be ALL CAPS. Max 80 words total.
            """
        case .steps:
            return """
            YOU MUST START YOUR RESPONSE WITH: [STEPS]
            
            EXACT FORMAT:
            [STEPS]
            1. **[Action verb]**: [Brief explanation]
            2. **[Action verb]**: [Brief explanation]
            3. **[Action verb]**: [Brief explanation]
            
            Max 5 steps. Each step = ONE line only. Max 80 words total.
            """
        case .example:
            return """
            YOU MUST START YOUR RESPONSE WITH: [SCENARIO]
            
            EXACT FORMAT:
            [SCENARIO]
            [A relatable real-world situation in 1-2 sentences]
            [CONNECTION]
            [How it connects to the concept in 1-2 sentences]
            [TAKEAWAY]
            [One sentence lesson.]
            
            All tags MUST be ALL CAPS. Max 80 words total.
            """
        case .simplify:
            return """
            YOU MUST START YOUR RESPONSE WITH: [SIMPLE]
            
            EXACT FORMAT:
            [SIMPLE]
            [2-3 sentences explaining in everyday language. No jargon. Like explaining to a friend who knows nothing about this.]
            
            Max 60 words after the tag.
            """
        case .keyPoints:
            return """
            YOU MUST START YOUR RESPONSE WITH: [KEYPOINTS]
            
            EXACT FORMAT:
            [KEYPOINTS]
            • [Most important point]
            • [Second point]
            • [Third point]
            
            Max 4 bullets. Each bullet = one clear sentence. Max 60 words total.
            """
        case .analogy:
            return """
            YOU MUST START YOUR RESPONSE WITH: [ANALOGY]
            
            EXACT FORMAT:
            [ANALOGY]
            **[Familiar comparison - kitchen, sports, daily life]**
            [MAPPING]
            • [Concept part] ↔ [Analogy part]
            • [Concept part] ↔ [Analogy part]
            [INSIGHT]
            [One sentence takeaway.]
            
            All tags MUST be ALL CAPS. Max 80 words total.
            """
        case .mistakes:
            return """
            YOU MUST START YOUR RESPONSE WITH: [MISTAKES]
            
            EXACT FORMAT:
            [MISTAKES]
            ✗ **[Error 1]** → [Why it's wrong]
            ✓ [How to do it correctly]
            ✗ **[Error 2]** → [Why it's wrong]
            ✓ [How to do it correctly]
            [EXAMPLE]
            [One concrete worked example: "e.g., To simplify 12/18: GCF=6, so 12/6=2, 18/6=3, answer=2/3"]
            
            All tags MUST be ALL CAPS. Max 2 mistakes. Max 100 words total.
            """
        }
    }
    
    // MARK: - Smart Quick Prompts
    
    /// Generates context-aware quick prompt suggestions based on user input and recent chat
    func generateQuickPrompts(
        partialInput: String,
        recentMessages: [ChatTurn],
        context: TutorContext
    ) -> [QuickPrompt] {
        var prompts: [QuickPrompt] = []
        let lowercased = partialInput.lowercased()
        
        // Static base prompts with specialized formats
        let basePrompts: [QuickPrompt] = [
            QuickPrompt(
                id: "simplify",
                label: "Simplify",
                icon: "lightbulb.min",
                prompt: "[FORMAT:simplify] Explain the main concept here in the simplest possible terms.",
                format: .simplify
            ),
            QuickPrompt(
                id: "example",
                label: "Example",
                icon: "globe",
                prompt: "[FORMAT:example] Give me a real-world example of this concept.",
                format: .example
            ),
            QuickPrompt(
                id: "mnemonic",
                label: "Memory trick",
                icon: "brain.head.profile",
                prompt: "[FORMAT:mnemonic] What's a catchy phrase or mnemonic that could help me study and remember the main ideas here?",
                format: .mnemonic
            ),
            QuickPrompt(
                id: "compare",
                label: "Compare",
                icon: "arrow.left.arrow.right",
                prompt: "[FORMAT:comparison] Contrast the two main ideas: where are they similar, where do they differ?",
                format: .comparison
            ),
            QuickPrompt(
                id: "steps",
                label: "Step by step",
                icon: "list.number",
                prompt: "[FORMAT:steps] Break down the main process or concept into clear steps.",
                format: .steps
            ),
            QuickPrompt(
                id: "keypoints",
                label: "Key points",
                icon: "list.bullet",
                prompt: "[FORMAT:keypoints] What are the most important points I need to know?",
                format: .keyPoints
            ),
            QuickPrompt(
                id: "analogy",
                label: "Analogy",
                icon: "arrow.triangle.branch",
                prompt: "[FORMAT:analogy] Help me understand this using a familiar everyday comparison.",
                format: .analogy
            ),
            QuickPrompt(
                id: "mistakes",
                label: "Common mistakes",
                icon: "exclamationmark.triangle",
                prompt: "[FORMAT:mistakes] What are the top mistakes, how to fix them, and one quick example?",
                format: .mistakes
            ),
            QuickPrompt(
                id: "why",
                label: "Why it matters",
                icon: "questionmark.circle",
                prompt: "[FORMAT:simple] In one paragraph (max 60 words), explain why this topic matters.",
                format: .simplify
            ),
            QuickPrompt(
                id: "formula",
                label: "Formulas",
                icon: "function",
                prompt: "[FORMAT:keypoints] List the key formulas as bullets with what each variable means.",
                format: .keyPoints
            ),
            QuickPrompt(
                id: "cheatsheet",
                label: "Cheat sheet",
                icon: "note.text",
                prompt: "[FORMAT:keypoints] Give me a tiny cheat sheet: 5 bullets max with the most actionable reminders.",
                format: .keyPoints
            )
        ]
        
        // If user is typing something, filter/prioritize based on input
        if !lowercased.isEmpty {
            // Check for specific query patterns and suggest relevant prompts
            if lowercased.contains("why") || lowercased.contains("how") {
                prompts.append(basePrompts.first { $0.id == "simplify" }!)
                prompts.append(basePrompts.first { $0.id == "steps" }!)
                prompts.append(basePrompts.first { $0.id == "why" }!)
            }
            
            if lowercased.contains("remember") || lowercased.contains("memorize") {
                prompts.append(basePrompts.first { $0.id == "mnemonic" }!)
            }
            
            if lowercased.contains("difference") || lowercased.contains("compare") || lowercased.contains("vs") {
                prompts.append(basePrompts.first { $0.id == "compare" }!)
            }
            
            if lowercased.contains("wrong") || lowercased.contains("mistake") || lowercased.contains("error") {
                prompts.append(basePrompts.first { $0.id == "mistakes" }!)
                prompts.append(basePrompts.first { $0.id == "cheatsheet" }!)
            }
            
            // Add remaining prompts not already added
            for prompt in basePrompts {
                if !prompts.contains(where: { $0.id == prompt.id }) {
                    prompts.append(prompt)
                }
            }
        } else {
            // No input - return base prompts in default order
            prompts = basePrompts
        }
        
        // Limit to 12 prompts for UI
        return Array(prompts.prefix(12))
    }
    
    /// Converts an AI response into flashcard format
    func convertToFlashcards(
        aiResponse: String,
        context: TutorContext
    ) async throws -> [(front: String, back: String)] {
        let systemPrompt = """
        You are a flashcard generator. You MUST output ONLY the exact tag format below. No other text allowed.
        """
        
        let userPrompt = """
        Convert this into flashcards. Create only as many as truly needed (1-3 max). If one flashcard captures it well, just make one.
        
        Output ONLY this format, nothing else:
        
        [FRONT]
        short term or question
        [BACK]
        brief answer
        [END]
        
        EXAMPLE OUTPUT:
        [FRONT]
        What is photosynthesis?
        [BACK]
        Process where plants convert sunlight to energy using chlorophyll.
        [END]
        
        STRICT RULES:
        - Start IMMEDIATELY with [FRONT] - no intro text
        - Each [FRONT] must have exactly one [BACK] and one [END]
        - Front: 2-8 words (term or question)
        - Back: 5-20 words (definition or answer)
        - NO markdown, NO bullets, NO numbering
        - Create 1-3 cards only (not more)
        
        TEXT TO CONVERT:
        \(aiResponse)
        """
        
        let rawContent = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        let content = normalizeTags(rawContent)
        
        var cards: [(String, String)] = []
        let blocks = content.components(separatedBy: "[END]")
        
        for block in blocks {
            let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBlock.isEmpty else { continue }
            
            var front = ""
            var back = ""
            
            let lines = trimmedBlock.components(separatedBy: .newlines)
            var currentTag = ""
            var currentText = ""
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine == "[FRONT]" || trimmedLine == "[BACK]" {
                    if !currentTag.isEmpty {
                        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty {
                            switch currentTag {
                            case "[FRONT]": front = value
                            case "[BACK]": back = value
                            default: break
                            }
                        }
                    }
                    currentTag = trimmedLine
                    currentText = ""
                } else {
                    currentText += line + "\n"
                }
            }
            
            if !currentTag.isEmpty {
                let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    switch currentTag {
                    case "[FRONT]": front = value
                    case "[BACK]": back = value
                    default: break
                    }
                }
            }
            
            if !front.isEmpty && !back.isEmpty {
                cards.append((front, back))
            }
        }
        
        if cards.isEmpty { throw AIError.parsingFailed }
        return Array(cards.prefix(5)) // Limit to 5 max
    }
    
}

