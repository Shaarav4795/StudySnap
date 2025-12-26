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
            Form {
                Section {
                    TextField("Folder Name", text: $folderName)
                        .font(.headline)
                } header: {
                    Text("Name")
                }
                
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(StudySetIcon.allIcons) { icon in
                            ZStack {
                                Circle()
                                    .fill(selectedIconId == icon.id ? themeManager.primaryColor : Color(uiColor: .secondarySystemFill))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: icon.systemName)
                                    .foregroundColor(selectedIconId == icon.id ? .white : .primary)
                                    .font(.system(size: 20))
                            }
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedIconId = icon.id
                                }
                                HapticsManager.shared.playTap()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
                }
            }
            .navigationTitle(folderToEdit == nil ? "New Folder" : "Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(folderToEdit == nil ? "Create" : "Save") {
                        saveFolder()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let folder = folderToEdit {
                    folderName = folder.name
                    selectedIconId = folder.iconId
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
