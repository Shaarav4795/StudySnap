import SwiftUI
import SwiftData

struct CreateFolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var folderName: String = ""
    @State private var selectedIconId: String = "folder"
    
    // If provided, we are in editing mode
    var folderToEdit: StudyFolder?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header with icon
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(themeManager.primaryGradient)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: folderToEdit == nil ? "folder.badge.plus" : "folder.badge.gearshape")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        
                        Text(folderToEdit == nil ? "New Folder" : "Edit Folder")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    
                    // Input field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("Folder Name", text: $folderName)
                            .font(.body)
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                    }
                    .padding(.horizontal)
                    
                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                            ForEach(StudySetIcon.allIcons) { icon in
                                Button(action: {
                                    HapticsManager.shared.playTap()
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedIconId = icon.id
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedIconId == icon.id ? themeManager.primaryColor : Color(uiColor: .tertiarySystemGroupedBackground))
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: icon.systemName)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedIconId == icon.id ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 40)
                .padding(.horizontal)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveFolder()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryColor)
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let folder = folderToEdit {
                    folderName = folder.name
                    selectedIconId = folder.iconId
                }
            }
        }
    }
    
    private func saveFolder() {
        HapticsManager.shared.playSuccess()
        
        if let folder = folderToEdit {
            folder.name = folderName
            folder.iconId = selectedIconId
        } else {
            let newFolder = StudyFolder(name: folderName, iconId: selectedIconId)
            modelContext.insert(newFolder)
        }
        
        dismiss()
    }
}
