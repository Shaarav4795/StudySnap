import Foundation

/// User-configurable model preference and BYOK storage.
enum AIModelPreference: String, CaseIterable, Identifiable {
    case automatic
    case openRouterOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .openRouterOnly: return "OpenRouter Only"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            return "Prefers Apple Intelligence when available; otherwise uses OpenRouter with your key."
        case .openRouterOnly:
            return "Always uses your OpenRouter BYOK key."
        }
    }
}

enum ModelSettings {
    enum Keys {
        static let preference = "ai.modelPreference"
        static let openRouterApiKey = "ai.openRouter.apiKey"
        static let openRouterModel = "ai.openRouter.model"
    }

    static let defaultOpenRouterModel = "openai/gpt-oss-20b:free"

    static func preference() async -> AIModelPreference {
        await MainActor.run {
            let raw = UserDefaults.standard.string(forKey: Keys.preference) ?? AIModelPreference.automatic.rawValue
            return AIModelPreference(rawValue: raw) ?? .automatic
        }
    }

    static func setPreference(_ value: AIModelPreference) async {
        await MainActor.run {
            UserDefaults.standard.set(value.rawValue, forKey: Keys.preference)
        }
    }

    static func openRouterApiKey() async -> String {
        await MainActor.run {
            UserDefaults.standard.string(forKey: Keys.openRouterApiKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    static func setOpenRouterApiKey(_ value: String) async {
        await MainActor.run {
            UserDefaults.standard.set(value, forKey: Keys.openRouterApiKey)
        }
    }

    static func openRouterModel() async -> String {
        await MainActor.run {
            let raw = UserDefaults.standard.string(forKey: Keys.openRouterModel)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return raw?.isEmpty == false ? raw! : defaultOpenRouterModel
        }
    }

    static func setOpenRouterModel(_ value: String) async {
        await MainActor.run {
            UserDefaults.standard.set(value, forKey: Keys.openRouterModel)
        }
    }

    nonisolated(unsafe) static var appleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }
}
