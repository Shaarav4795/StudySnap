import Foundation

enum AIError: Error {
    case generationFailed
    case invalidResponse
    case parsingFailed
    case apiError(String)
}

actor AIService {
    static let shared = AIService()
    
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
    
    // Resolved at init time from Secrets.plist (not checked in)
    private let apiKey = Secrets.value(for: .openRouterApiKey) ?? ""
    private let model = Secrets.value(for: .openRouterModel) ?? "openai/gpt-oss-20b:free"
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
        // Fail fast if the API key is missing to avoid confusing network errors
        guard apiKey.isEmpty == false else {
            throw AIError.apiError("Missing OpenRouter API key. Add OPENROUTER_API_KEY to Secrets.plist.")
        }

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
        
        // Add a small randomised delay before the request to mitigate rate-limiting
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
            let systemPrompt = "You are a helpful study assistant. Summarise the text provided by the user."
            let styleInstruction: String
            if style == .bulletPoints {
                styleInstruction = "Use bullet points ONLY. Output each bullet as a separate line that starts with a hyphen and a single space ('- '). Do NOT output paragraphs or place hyphens at the start of lines unless they are intended as bullets. Do NOT break a single bullet across multiple lines. Example:\n- First concise point\n- Second concise point"
            } else {
                styleInstruction = "Do NOT use bullet points or leading hyphens. Write a single concise paragraph with no line breaks and avoid using '-' at the start of any line."
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
            Summarise the following text. \(styleInstruction)
            Target word count: approximately \(wordCount) words.
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
            let systemPrompt = "You are a helpful study assistant. You generate multiple choice questions."
            let userPrompt = """
            Generate \(count) multiple choice study questions based on the following text.
            
            Use the following EXACT format for each question:
            
            [QUESTION]
            The question text here
            [ANSWER]
            The correct answer text
            [OPTION]
            Option 1 text
            [OPTION]
            Option 2 text
            [OPTION]
            Option 3 text
            [OPTION]
            Option 4 text
            [EXPLANATION]
            The explanation text
            [END]
            
            IMPORTANT:
            1. Do NOT use JSON. Use the custom format above.
            2. Ensure each question is INDEPENDENT.
            
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
            
            let content = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            
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
                                case "[QUESTION]": question = value
                                case "[ANSWER]": answer = value
                                case "[OPTION]": options.append(value)
                                case "[EXPLANATION]": explanation = value
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
                        case "[QUESTION]": question = value
                        case "[ANSWER]": answer = value
                        case "[OPTION]": options.append(value)
                        case "[EXPLANATION]": explanation = value
                        default: break
                        }
                    }
                }
                
                if !question.isEmpty && !answer.isEmpty && !options.isEmpty {
                    questions.append((question, answer, options, explanation))
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
            let systemPrompt = "You are a helpful study assistant. You generate flashcards."
            let userPrompt = """
            Generate \(count) flashcards (like in Quizlet) based on the following text.
            
            Use the following EXACT format for each flashcard:
            
            [FRONT]
            Term text
            [BACK]
            Definition text
            [END]
            
            IMPORTANT:
            1. Do NOT use JSON. Use the custom format above.
            2. Keep the 'front' (term) very short (3-9 words) and the 'back' (definition) concise (under 20 words).
            
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
            
            let content = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            
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
            let systemPrompt = "You are an expert educator and tutor. You create comprehensive, easy-to-follow learning guides on any topic."
            let styleInstruction: String
            if style == .bulletPoints {
                styleInstruction = "Use bullet points ONLY for lists. Output each bullet as a separate line that starts with a hyphen and a single space ('- '). Do NOT place hyphens at the start of lines unless that line is a bullet. Numbered steps are OK but prefer hyphen bullets. Keep each bullet concise and do not split a bullet over multiple lines. Example:\n- Key concept one\n- Key concept two"
            } else {
                styleInstruction = "Do NOT use bullet points or leading hyphens. Write clear, flowing paragraphs with normal sentence breaks (but avoid forced newlines). Prefer full paragraphs rather than line-by-line lists."
            }
            let difficultyInstruction: String
            switch difficulty {
            case .beginner:
                difficultyInstruction = "Explain as if teaching someone completely new to this topic. Start with the basics and avoid jargon."
            case .intermediate:
                difficultyInstruction = "Assume some foundational knowledge. Include practical examples and common techniques."
            case .advanced:
                difficultyInstruction = "Provide in-depth coverage with advanced concepts, edge cases, and expert-level insights."
            }
            
            let userPrompt = """
            Create a comprehensive learning guide about: \(topic)
            
            \(styleInstruction)
            Target word count: approximately \(wordCount) words.
            Difficulty level: \(difficulty.rawValue) (\(difficultyInstruction))
            
            Structure your guide to include:
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
            let systemPrompt = "You are an expert educator. You create educational quiz questions to test understanding of topics."
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
            Generate \(count) multiple choice quiz questions to help someone learn about: \(topic)
            
            Difficulty: \(difficulty.rawValue) - \(difficultyInstruction)
            
            Use the following EXACT format for each question:
            
            [QUESTION]
            The question text here
            [ANSWER]
            The correct answer text
            [OPTION]
            Option 1 text
            [OPTION]
            Option 2 text
            [OPTION]
            Option 3 text
            [OPTION]
            Option 4 text
            [EXPLANATION]
            The explanation text (explain why this answer is correct and teach the concept)
            [END]
            
            IMPORTANT:
            1. Do NOT use JSON. Use the custom format above.
            2. Make questions educational - they should teach as well as test.
            3. Include clear explanations that help the learner understand the concept.
            4. Ensure each question is INDEPENDENT of each other.
            
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
            
            let content = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            
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
                                case "[QUESTION]": question = value
                                case "[ANSWER]": answer = value
                                case "[OPTION]": options.append(value)
                                case "[EXPLANATION]": explanation = value
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
                        case "[QUESTION]": question = value
                        case "[ANSWER]": answer = value
                        case "[OPTION]": options.append(value)
                        case "[EXPLANATION]": explanation = value
                        default: break
                        }
                    }
                }
                
                if !question.isEmpty && !answer.isEmpty && !options.isEmpty {
                    questions.append((question, answer, options, explanation))
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
            let systemPrompt = "You are an expert educator. You create educational flashcards to help people learn new topics (like in Quizlet)."
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
            Generate \(count) educational flashcards to help someone learn about: \(topic)
            
            Difficulty: \(difficulty.rawValue) - \(difficultyInstruction)
            
            Use the following EXACT format for each flashcard:
            
            [FRONT]
            Term, concept, or question
            [BACK]
            Definition, explanation, or answer
            [END]
            
            IMPORTANT:
            1. Do NOT use JSON. Use the custom format above.
            2. Keep the 'front' concise (a term, concept, or short question).
            3. Make the 'back' educational and clear (definition or explanation).
            4. Cover key concepts someone needs to know about this topic.
            5. The "front" of a flashcard should be 3-9 words, and the "back" should be under 20 words.
            
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
            
            let content = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            
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
            let systemPrompt = "You are an expert educational advisor. You suggest interesting and educational topics for students to learn."
            
            let topicsContext = existingTopics.isEmpty ? 
                "The user is new and has no study history." :
                "The user has studied: \(existingTopics.joined(separator: ", "))"
            
            let userPrompt = """
            \(topicsContext)
            
            Suggest 5 interesting and diverse topics for the user to learn next. Make sure topics are different from what they've already studied.
            
            Use the following EXACT format for each suggestion:
            
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
            
            IMPORTANT:
            1. Do NOT use JSON. Use the custom format above.
            2. Make topics diverse and interesting.
            3. Consider educational value and relevance.
            4. Only use valid SF Symbol names for icons.
            """
            
            let content = try await performRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
            
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

