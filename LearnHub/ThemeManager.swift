import SwiftUI
import SwiftData
import Combine

// MARK: - Theme manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var primaryColor: Color = .blue
    @Published var secondaryColor: Color = .cyan
    @Published var gradientColors: [Color] = [.blue, .cyan]
    
    private init() {}
    
    @MainActor
    func updateTheme(for themeId: String) {
        guard let theme = ThemeItem.theme(for: themeId) else {
            // Fallback to the default theme when an ID is unknown.
            primaryColor = .blue
            secondaryColor = .cyan
            gradientColors = [.blue, .cyan]
            return
        }
        
        primaryColor = colorFromString(theme.primaryColor)
        secondaryColor = colorFromString(theme.secondaryColor)
        
        if theme.id == "rainbow" {
            gradientColors = [.red, .orange, .yellow, .green, .blue, .purple]
        } else {
            gradientColors = [primaryColor, secondaryColor]
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "cyan": return .cyan
        case "teal": return .teal
        case "orange": return .orange
        case "pink": return .pink
        case "green": return .green
        case "mint": return .mint
        case "purple": return .purple
        case "indigo": return .indigo
        case "red": return .red
        case "yellow": return .yellow
        case "rainbow": return .purple
        case "navy": return Color(red: 0.0, green: 0.0, blue: 0.5)
        case "charcoal": return Color(red: 0.2, green: 0.2, blue: 0.25)
        case "slate": return Color(red: 0.4, green: 0.45, blue: 0.5)
        case "magenta": return Color(red: 1.0, green: 0.0, blue: 0.5)
        case "violet": return Color(red: 0.5, green: 0.0, blue: 1.0)
        default: return .blue
        }
    }
    
    // Convenience gradients derived from the current theme colors.
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var horizontalGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Theme-aware view modifier

struct ThemedAccent: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .tint(themeManager.primaryColor)
    }
}

extension View {
    func themedAccent() -> some View {
        modifier(ThemedAccent())
    }
}
