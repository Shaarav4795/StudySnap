import Foundation

/// Lightweight secrets loader for values stored in Secrets.plist (gitignored).
/// Provides trimmed string access with optional defaults.
enum Secrets {
    enum Key: String {
        case openRouterApiKey = "OPENROUTER_API_KEY"
        case openRouterModel = "OPENROUTER_MODEL"
    }

    private static var cached: [String: Any]?

    private static func load() -> [String: Any]? {
        if let cached { return cached }
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }
        cached = dict
        return dict
    }

    static func value(for key: Key) -> String? {
        guard let raw = load()?[key.rawValue] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
