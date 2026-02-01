import SwiftUI
import SwiftData

struct MoveToFolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    let studySet: StudySet
    let studyFolders: [StudyFolder]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Sheet header for moving a study set.
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(themeManager.primaryGradient)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        
                        Text("Move to Folder")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                    }
                    
                    if studyFolders.isEmpty {
                        ContentUnavailableView {
                            Label("No Folders", systemImage: "folder")
                        } description: {
                            Text("Create a folder first to move this study set.")
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(studyFolders) { folder in
                                    Button {
                                        withAnimation {
                                            studySet.folder = folder
                                        }
                                        HapticsManager.shared.playSuccess()
                                        dismiss()
                                    } label: {
                                        HStack {
                                            ZStack {
                                                Circle()
                                                    .fill(themeManager.primaryColor.opacity(0.1))
                                                    .frame(width: 40, height: 40)
                                                
                                                Image(systemName: StudySetIcon.icon(for: folder.iconId)?.systemName ?? "folder.fill")
                                                    .foregroundColor(themeManager.primaryColor)
                                            }
                                            
                                            Text(folder.name)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            if studySet.folder == folder {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(themeManager.primaryColor)
                                            }
                                        }
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 40)
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
            }
        }
    }
}
