import SwiftUI
import Shimmer
import Lottie

struct AppLoadingOverlay: View {
    let title: String
    let subtitle: String
    let animationName: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                CelebrationLottieView(animationName: animationName, play: true, loopMode: .loop)
                    .frame(width: 72, height: 72)

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 220, height: 12)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 170, height: 12)
                }
                .shimmering()
            }
            .padding(22)
            .frame(maxWidth: 330)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 6)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}
