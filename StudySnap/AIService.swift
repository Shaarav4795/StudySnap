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
        if #available(iOS 26.0, *) {
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
            let notice = "Apple Intelligence requires iOS 26+ and supported hardware. Falling back to OpenRouter (BYOK)."
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
                difficultyInstruction = "Use simple language suitable for a beginner. Avoid jargon where possible."
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
    
    // MARK: - Topic Suggestions (Gamification Feature)
    
    /// Generates AI-powered topic suggestions based on user's study history
    func generateTopicSuggestions(existingTopics: [String]) async throws -> [TopicSuggestion] {
        do {
            let systemPrompt = "You are an expert educational advisor. You suggest topics with STRICT tag formatting. Do not add any text outside the required tags. No markdown headings or bullets outside tags."
            
            let topicsContext = existingTopics.isEmpty ? 
                "The user is new and has no study history." :
                "The user has studied: \(existingTopics.joined(separator: ", "))"
            
            let userPrompt = """
            \(topicsContext)

            Suggest 5 interesting and diverse topics for the user to learn next. Make sure topics are different from what they've already studied.

            Use the following EXACT format for each suggestion (no extra blank lines between tags):

            [TITLE]
            Topic title (3-7 words)
            [DESCRIPTION]
            Brief description of what they'll learn (1-2 sentences)
            [CATEGORY]
            One of: Technology, Science, History, Arts, Business, Language, Health, Mathematics, Philosophy, or Other
            [DIFFICULTY]
            One of: Beginner, Intermediate, or Advanced
            [TIME]
            Estimated study time (e.g., "1-2 hours", "2-3 hours")
            [ICON]
            SF Symbol name (e.g., brain, atom, building.columns, chart.line.uptrend.xyaxis, book, globe, heart, function, lightbulb)
            [END]

            IMPORTANT - FOLLOW ALL:
            1) Do NOT use JSON or markdown.
            2) Keep EXACT tags as shown. No extra tags or bullets.
            3) Make topics diverse and interesting.
            4) Only use valid SF Symbol names for icons.
            """
            
            let rawContent = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            let content = normalizeTags(rawContent)
            
            var suggestions: [TopicSuggestion] = []
            let blocks = content.components(separatedBy: "[END]")
            
            for block in blocks {
                let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedBlock.isEmpty else { continue }
                
                var title = ""
                var description = ""
                var category = ""
                var difficulty = ""
                var time = ""
                var icon = ""
                
                let lines = trimmedBlock.components(separatedBy: .newlines)
                var currentTag = ""
                var currentText = ""
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if ["[TITLE]", "[DESCRIPTION]", "[CATEGORY]", "[DIFFICULTY]", "[TIME]", "[ICON]"].contains(trimmedLine) {
                        if !currentTag.isEmpty {
                            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !value.isEmpty {
                                switch currentTag {
                                case "[TITLE]": title = value
                                case "[DESCRIPTION]": description = value
                                case "[CATEGORY]": category = value
                                case "[DIFFICULTY]": difficulty = value
                                case "[TIME]": time = value
                                case "[ICON]": icon = value
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
                        case "[TITLE]": title = value
                        case "[DESCRIPTION]": description = value
                        case "[CATEGORY]": category = value
                        case "[DIFFICULTY]": difficulty = value
                        case "[TIME]": time = value
                        case "[ICON]": icon = value
                        default: break
                        }
                    }
                }
                
                if !title.isEmpty && !description.isEmpty {
                    suggestions.append(TopicSuggestion(
                        title: title,
                        description: description,
                        category: category.isEmpty ? "Other" : category,
                        difficulty: difficulty.isEmpty ? "Intermediate" : difficulty,
                        estimatedTime: time.isEmpty ? "1-2 hours" : time,
                        icon: icon.isEmpty ? "lightbulb" : icon
                    ))
                }
            }
            
            if suggestions.isEmpty { throw AIError.parsingFailed }
            return suggestions
            
        } catch {
            print("AI Generation failed: \(error). Falling back to fallback suggestions.")
            return TopicSuggestion.fallbackSuggestions
        }
    }
}

