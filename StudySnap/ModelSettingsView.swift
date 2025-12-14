import SwiftUI

struct ModelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ModelSettings.Keys.preference) private var preferenceRaw: String = AIModelPreference.automatic.rawValue
    @AppStorage(ModelSettings.Keys.openRouterApiKey) private var openRouterApiKey: String = ""
    @State private var showHelp = false

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
                .onChange(of: preferenceBinding.wrappedValue) { _, _ in
                    HapticsManager.shared.playTap()
                }

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
                            Text("Requires iOS 26+, supported hardware, and Apple Intelligence enabled in Settings. Automatic will fall back to OpenRouter with your key.")
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
                
                Button(action: {
                    HapticsManager.shared.playTap()
                    showHelp = true
                }) {
                    Label("How to get a free API key", systemImage: "info.circle")
                }

                if openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Your OpenRouter API key is required to use OpenRouter models.").font(.footnote).foregroundColor(.secondary)
                } else {
                    Text("Your OpenRouter API key is required to use OpenRouter models.").font(.footnote).foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Model Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelp) {
            OpenRouterHelpView()
        }
    }
}

struct OpenRouterHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "key.radiowaves.forward.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("OpenRouter API")
                                    .font(.headline)
                                Text("Free Access")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 4)
                        
                        Text("To use advanced AI models when Apple Intelligence isn't available, you need a free OpenRouter API key.")
                            .font(.callout)
                    }
                    .padding(.vertical, 8)
                }

                Section("Instructions") {
                    StepView(number: 1, title: "Create Account", description: "Sign up at openrouter.ai using Google or GitHub.", icon: "person.badge.plus")
                    StepView(number: 2, title: "Generate Key", description: "Go to Settings > Keys and create a new API key.", icon: "key")
                    StepView(number: 3, title: "Connect", description: "Copy the key and paste it into the field in StudySnap.", icon: "arrow.right.doc.on.clipboard")
                }

                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Payment Required")
                                .font(.headline)
                            Text("OpenRouter offers free models. You do not need to add a credit card to get started.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Link(destination: URL(string: "https://openrouter.ai/settings/keys")!) {
                        Label("Open OpenRouter Settings", systemImage: "safari")
                    }
                }
            }
            .navigationTitle("Setup Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                HapticsManager.shared.playTap()
                                dismiss()
                            }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
