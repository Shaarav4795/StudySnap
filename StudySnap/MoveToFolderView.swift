import SwiftUI
import SwiftData

struct MoveToFolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StudyFolder.dateCreated, order: .reverse) private var studyFolders: [StudyFolder]
    
    let studySet: StudySet
    
    var body: some View {
        NavigationStack {
            List {
                if studyFolders.isEmpty {
                    ContentUnavailableView {
                        Label("No Folders", systemImage: "folder")
                    } description: {
                        Text("Create a folder first to move this study set.")
                    }
                } else {
                    ForEach(studyFolders) { folder in
                        Button {
                            withAnimation {
                                studySet.folder = folder
                            }
                            HapticsManager.shared.playSuccess()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(folder.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if studySet.folder == folder {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
