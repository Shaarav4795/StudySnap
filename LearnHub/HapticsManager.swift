import Foundation
import CoreHaptics
import UIKit

/// Centralized Core Haptics helper so we can keep taps consistent and lightweight.
final class HapticsManager {
    static let shared = HapticsManager()

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private let queue = DispatchQueue(label: "com.learnhub.haptics", qos: .userInitiated)

    private init() { }

    func prepareEngine() {
        guard supportsHaptics else { return }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.ensureEngine()
                try self.engine?.start()
            } catch {
                print("Haptics prepare failed: \(error.localizedDescription)")
            }
        }
    }

    func playTap(intensity: Float = 0.55, sharpness: Float = 0.45) {
        guard supportsHaptics else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            do {
                try self.ensureEngine()
                try self.engine?.start()

                let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try self.engine?.makePlayer(with: pattern)
                try player?.start(atTime: CHHapticTimeImmediate)
            } catch {
                print("Haptics play failed: \(error.localizedDescription)")
            }
        }
    }

    func playSuccess() {
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    func success() {
        playSuccess()
    }

    func playError() {
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    func error() {
        playError()
    }
    
    func lightImpact() {
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Private

    private func ensureEngine() throws {
        if engine == nil {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { reason in
                print("Haptics stopped: \(reason.rawValue)")
            }
        }
    }
}
