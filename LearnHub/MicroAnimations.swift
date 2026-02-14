import SwiftUI
import UIKit
import Lottie

struct PressScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct CelebrationLottieView: UIViewRepresentable {
    var animationName: String
    var play: Bool
    var loopMode: LottieLoopMode = .playOnce

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        container.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.animationView = animationView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }
        animationView.loopMode = loopMode
        animationView.animation = LottieAnimation.named(animationName)

        if play {
            if animationView.animation != nil {
                animationView.play()
            }
        } else {
            animationView.stop()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var animationView: LottieAnimationView?
    }
}