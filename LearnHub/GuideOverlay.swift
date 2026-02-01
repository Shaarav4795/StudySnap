import SwiftUI

// MARK: - Guide targeting

enum GuideTarget: Hashable {
    case homeCreate
    case inputGenerate
    case questionsStartQuiz
    case flashcardsDeck
    case profileHeader
    case settingsTab
    case homeTab
    case modelPicker
}

struct GuideTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [GuideTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [GuideTarget: Anchor<CGRect>], nextValue: () -> [GuideTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func guideTarget(_ target: GuideTarget) -> some View {
        anchorPreference(key: GuideTargetPreferenceKey.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }
}

// MARK: - Overlay renderer

struct GuideOverlayLayer: View {
    @ObservedObject var guideManager: GuideManager
    let accent: Color
    let prefs: [GuideTarget: Anchor<CGRect>]
    let geometry: GeometryProxy
    var selectedTab: AppTab = .home
    let onSkip: () -> Void
    let onAdvance: (() -> Void)?

    var body: some View {
        guard let step = guideManager.currentStep else { return AnyView(EmptyView()) }
        let target = targetFor(step: step)
        let callout = calloutContent(for: step)
        let rect = target.flatMap { prefs[$0] }.map { geometry[$0] }

        return AnyView(ZStack(alignment: .topLeading) {
            if let rect = rect {
                HighlightShape(rect: rect)
                    .fill(Color.black.opacity(0.55))
                    .blendMode(.destinationOut)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: rect)

                GlowHighlight(rect: rect, accent: accent)
                    .allowsHitTesting(false)

                if !guideManager.isCollapsed {
                    callout
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
                        .overlay(alignment: .topTrailing) {
                            Button(action: {
                                HapticsManager.shared.playTap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    guideManager.collapse()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .background(Circle().fill(.regularMaterial))
                            }
                            .padding(10)
                        }
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)
                        .position(calloutPosition(around: rect, in: geometry.size, step: step))
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            } else {
                // When no target rect exists (e.g., switching tabs), show the callout alone.
                if !guideManager.isCollapsed {
                    callout
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
                                .frame(maxWidth: 320)
                                .fixedSize(horizontal: false, vertical: true)
                                .position(calloutPosition(around: nil, in: geometry.size, step: step))
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }

            if guideManager.isCollapsed {
                GuideBadge {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        guideManager.expand()
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .compositingGroup()
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: guideManager.isCollapsed)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step))
    }

    private func calloutContent(for step: GuideManager.Step) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: step))
                    .font(.title2)
                    .foregroundColor(accent)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(calloutTitle(for: step))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(stepLabel(for: step))
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }
            }
            
            Text(calloutMessage(for: step))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 12) {
                if let onAdvance {
                    Button(action: {
                        HapticsManager.shared.playTap()
                        onAdvance()
                    }) {
                        Text("Next")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .clipShape(Capsule())
                }
                
                Button(action: {
                    HapticsManager.shared.playTap()
                    onSkip()
                }) {
                    Text("Skip tutorial")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
    }
    
    private func icon(for step: GuideManager.Step) -> String {
        switch step {
        case .configureModel: return "gear"
        case .createFirstSet: return "plus"
        case .tuneOptions, .generateSet: return "slider.horizontal.3"
        case .openSet: return "folder"
        case .exploreQuiz: return "checkmark.circle"
        case .exploreFlashcards: return "rectangle.on.rectangle.angled"
        case .exploreGamification: return "flame"
        }
    }

    private func stepLabel(for step: GuideManager.Step) -> String {
        switch step {
        case .configureModel: return "Step 1 of 6"
        case .createFirstSet: return "Step 2 of 6"
        case .tuneOptions, .generateSet: return "Step 3 of 6"
        case .openSet: return "Step 4 of 6"
        case .exploreQuiz: return "Step 5 of 6"
        case .exploreFlashcards, .exploreGamification: return "Step 6 of 6"
        }
    }

    private func targetFor(step: GuideManager.Step) -> GuideTarget? {
        switch step {
        case .configureModel:
            return selectedTab == .settings ? .modelPicker : nil
        case .createFirstSet:
            return selectedTab == .home ? .homeCreate : nil
        case .tuneOptions, .generateSet: return .inputGenerate
        case .exploreQuiz: return .questionsStartQuiz
        case .exploreFlashcards: return .flashcardsDeck
        case .exploreGamification: return .profileHeader
        case .openSet: return nil
        }
    }

    private func calloutTitle(for step: GuideManager.Step) -> String {
        switch step {
        case .configureModel: return "Configure AI Model"
        case .createFirstSet: return "Create your first set"
        case .tuneOptions, .generateSet: return "Tune options & generate"
        case .openSet: return "Open your new set"
        case .exploreQuiz: return "Start a quick quiz"
        case .exploreFlashcards: return "Review with flashcards"
        case .exploreGamification: return "Track your progress"
        }
    }

    private func calloutMessage(for step: GuideManager.Step) -> String {
        switch step {
        case .configureModel:
            return selectedTab == .settings
            ? "Set up your preferred AI model or add your API key."
            : "Tap the Settings tab below, then set your preferred model."
        case .createFirstSet:
            return selectedTab == .home
            ? "Tap the + button to begin."
            : "Tap the Home tab below, then hit + to start."
        case .tuneOptions, .generateSet: return "Adjust counts/difficulty, then Generate."
        case .openSet: return "Tap the study set you just created to enter."
        case .exploreQuiz: return "Open Questions and tap Start Quiz."
        case .exploreFlashcards: return "Open Flashcards to review your set."
        case .exploreGamification: return "Track streaks, coins, and achievements in the tabs below."
        }
    }

    private func calloutPosition(around rect: CGRect?, in container: CGSize, step: GuideManager.Step) -> CGPoint {
        // Without a rect, anchor the callout above the tab bar.
        let padding: CGFloat = 16
        let calloutWidth: CGFloat = 300
        let calloutHeight: CGFloat = 160

        if rect == nil {
            let tabBarHeight = geometry.safeAreaInsets.bottom + 49
            let y = container.height - tabBarHeight - calloutHeight/1.6
            return CGPoint(x: container.width / 2, y: y)
        }

        guard let rect else { return CGPoint(x: container.width/2, y: container.height/2) }

        if step == .exploreQuiz {
            return CGPoint(x: container.width / 2, y: container.height * 0.45)
        }

        let topY = rect.minY - calloutHeight/2 - padding
        let bottomY = rect.maxY + calloutHeight/2 + padding

        if rect.maxY > container.height * 0.8 {
            return CGPoint(x: container.width / 2, y: topY)
        }

        let useBottom = bottomY + calloutHeight/2 < container.height - padding
        let y: CGFloat = useBottom ? bottomY : topY
        let x = min(max(rect.midX, calloutWidth/2 + padding), container.width - calloutWidth/2 - padding)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Highlight shapes

private struct HighlightShape: Shape {
    let rect: CGRect
    func path(in _: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect.insetBy(dx: -10, dy: -10), cornerRadius: 14).cgPath)
    }
}

private struct GlowHighlight: View {
    let rect: CGRect
    let accent: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(accent.opacity(0.18))
            .frame(width: rect.width + 28, height: rect.height + 28)
            .position(x: rect.midX, y: rect.midY)
            .blur(radius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(accent.opacity(0.35), lineWidth: 2)
                    .frame(width: rect.width + 18, height: rect.height + 18)
                    .position(x: rect.midX, y: rect.midY)
                    .blur(radius: 2)
            )
    }
}
