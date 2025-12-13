import SwiftUI
import Combine

// MARK: - App Onboarding Guide

/// Drives the post-tutorial in-product guide that teaches core flows.
final class GuideManager: ObservableObject {
    static let shared = GuideManager()

    enum Step: Int, CaseIterable, Codable {
        case configureModel
        case createFirstSet
        case tuneOptions
        case generateSet
        case openSet
        case exploreQuiz
        case exploreFlashcards
        case openProfile
        case exploreGamification
    }

    @AppStorage("hasCompletedGuide") private var hasCompletedGuide: Bool = false
    @Published var currentStep: Step? = nil
    @Published var isCollapsed: Bool = false

    private init() {}

    var isActive: Bool { currentStep != nil }

    func startIfNeededAfterTutorial() {
        // For testing, always restart guide after tutorial finishes
        hasCompletedGuide = false
        isCollapsed = false
        currentStep = .configureModel
    }

    func skipGuide() {
        hasCompletedGuide = true
        currentStep = nil
        isCollapsed = false
    }

    func advanceAfterConfiguredModel() {
        guard currentStep == .configureModel else { return }
        isCollapsed = false
        currentStep = .createFirstSet
    }

    func advanceAfterTappedCreate() {
        guard currentStep == .createFirstSet else { return }
        isCollapsed = false
        currentStep = .tuneOptions
    }

    func advanceAfterGeneratedSet() {
        guard currentStep == .tuneOptions || currentStep == .generateSet else { return }
        isCollapsed = false
        currentStep = .openSet
    }

    func advanceAfterOpenedSet() {
        guard currentStep == .openSet else { return }
        isCollapsed = false
        currentStep = .exploreQuiz
    }

    func advanceAfterVisitedQuiz() {
        guard currentStep == .exploreQuiz else { return }
        isCollapsed = false
        currentStep = .exploreFlashcards
    }

    func advanceAfterVisitedFlashcards() {
        guard currentStep == .exploreFlashcards else { return }
        isCollapsed = false
        currentStep = .openProfile
    }

    func advanceAfterOpenedProfile() {
        guard currentStep == .openProfile else { return }
        isCollapsed = false
        currentStep = .exploreGamification
    }

    func finishGamification() {
        guard currentStep == .exploreGamification else { return }
        hasCompletedGuide = true
        currentStep = nil
        isCollapsed = false
    }

    func collapse() {
        isCollapsed = true
    }
    
    func expand() {
        isCollapsed = false
    }
}

// MARK: - Guide UI Helpers

struct GuideCallout: View {
    let title: String
    let message: String
    let accent: Color
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var showSkip: Bool = true
    var skip: (() -> Void)? = nil
    var onCollapse: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                if let onCollapse = onCollapse {
                    Button {
                        onCollapse()
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundColor(.secondary)
                        Text("Hide")
                    }
                    .font(.subheadline)
                }
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accent)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                if showSkip, let skip = skip {
                    Button("Skip", action: skip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

struct GuideBadge: View {
    let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                Text("Show guide")
                    .font(.subheadline.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        }
    }
}

struct PulsingTarget: View {
    let diameter: CGFloat
    let color: Color

    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(color.opacity(0.7), lineWidth: 3)
            .frame(width: diameter, height: diameter)
            .scaleEffect(animate ? 1.12 : 0.88)
            .opacity(animate ? 0.9 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}
