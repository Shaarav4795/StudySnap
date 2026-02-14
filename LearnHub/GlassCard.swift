import SwiftUI

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strokeOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, strokeOpacity: Double = 0.2) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}
