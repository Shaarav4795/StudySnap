import SwiftUI

struct ModelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ModelSettings.Keys.preference) private var preferenceRaw: String = AIModelPreference.automatic.rawValue
    @AppStorage(ModelSettings.Keys.openRouterApiKey) private var openRouterApiKey: String = ""

    private var preferenceBinding: Binding<AIModelPreference> {
        Binding {
            AIModelPreference(rawValue: preferenceRaw) ?? .automatic
        } set: { newValue in
            preferenceRaw = newValue.rawValue
        }
    }

    private var appleAvailable: Bool {
        ModelSettings.appleIntelligenceAvailable
    }

    var body: some View {
        Form {
            Section("Model Preference") {
                Picker("Model", selection: preferenceBinding) {
                    ForEach(AIModelPreference.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(preferenceBinding.wrappedValue.detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Section("Availability & Fallback") {
                if appleAvailable {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Intelligence available")
                                .font(.subheadline).bold()
                            Text("Automatic prefers on-device. If it fails, we fall back to OpenRouter with your key.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                } else {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Intelligence not available")
                                .font(.subheadline).bold()
                            Text("Requires iOS 26+ and supported hardware. Automatic will fall back to OpenRouter with your key.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }

            Section("OpenRouter BYOK") {
                TextField("Paste your OpenRouter API key", text: $openRouterApiKey)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled(true)

                if openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Required when using OpenRouter (automatic fallback or OpenRouter-only).").font(.footnote).foregroundColor(.secondary)
                } else {
                    Text("Your OpenRouter API key (https://openrouter.ai/settings/keys)").font(.footnote).foregroundColor(.secondary)
                }
            }

            Section {
                Text("Automatic prefers Apple Intelligence on-device. If your device/OS cannot run it or it fails, we will use OpenRouter with your BYOK key. OpenRouter defaults to \(ModelSettings.defaultOpenRouterModel).")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .navigationTitle("Model Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
