import Foundation

private class BundleFinder {}

/// Lightweight secrets loader for values stored in Secrets.plist (gitignored).
/// Provides trimmed string access with optional defaults.
enum Secrets {
    enum Key: String {
        case openRouterApiKey = "OPENROUTER_API_KEY"
        case openRouterModel = "OPENROUTER_MODEL"
    }

    // Removed unsafe global cache to avoid concurrency issues and MainActor requirements.
    // Plist loading is fast enough to do on demand for this use case.
    private static func load() -> [String: Any]? {
        // Use Bundle(for:) to avoid Bundle.main which is MainActor isolated
        let bundle = Bundle(for: BundleFinder.self)
        guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }
        return dict
    }

    static func value(for key: Key) -> String? {
        guard let raw = load()?[key.rawValue] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
