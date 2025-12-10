import Foundation
import SwiftData

enum StudySetMode: String, Codable {
    case content = "content"  // Generated from source material
    case topic = "topic"      // Generated from topic description
}

// MARK: - Study Set Icons

struct StudySetIcon: Identifiable, Hashable {
    let id: String
    let name: String
    let systemName: String
    
    static let allIcons: [StudySetIcon] = [
        StudySetIcon(id: "book", name: "Book", systemName: "book.closed.fill"),
        StudySetIcon(id: "brain", name: "Brain", systemName: "brain.head.profile"),
        StudySetIcon(id: "lightbulb", name: "Lightbulb", systemName: "lightbulb.fill"),
        StudySetIcon(id: "star", name: "Star", systemName: "star.fill"),
        StudySetIcon(id: "bookmark", name: "Bookmark", systemName: "bookmark.fill"),
        StudySetIcon(id: "folder", name: "Folder", systemName: "folder.fill"),
        StudySetIcon(id: "doc", name: "Document", systemName: "doc.text.fill"),
        StudySetIcon(id: "graduationcap", name: "Graduation", systemName: "graduationcap.fill"),
        StudySetIcon(id: "pencil", name: "Pencil", systemName: "pencil.circle.fill"),
        StudySetIcon(id: "atom", name: "Science", systemName: "atom"),
        StudySetIcon(id: "function", name: "Math", systemName: "function"),
        StudySetIcon(id: "globe", name: "Geography", systemName: "globe.americas.fill"),
        StudySetIcon(id: "music", name: "Music", systemName: "music.note"),
        StudySetIcon(id: "paintpalette", name: "Art", systemName: "paintpalette.fill"),
        StudySetIcon(id: "heart", name: "Health", systemName: "heart.fill"),
        StudySetIcon(id: "laptopcomputer", name: "Computer", systemName: "laptopcomputer"),
        StudySetIcon(id: "building", name: "History", systemName: "building.columns.fill"),
        StudySetIcon(id: "leaf", name: "Nature", systemName: "leaf.fill"),
        StudySetIcon(id: "flask", name: "Chemistry", systemName: "flask.fill"),
        StudySetIcon(id: "sparkles", name: "Magic", systemName: "sparkles"),
    ]
    
    static let defaultIcon = allIcons[0]
    
    static func icon(for id: String) -> StudySetIcon? {
        allIcons.first { $0.id == id }
    }
}

@Model
final class StudySet {
    var id: UUID
    var title: String
    var originalText: String
    var dateCreated: Date
    var summary: String?
    var mode: String = "content"  // "content" or "topic" - default to content for migration
    var iconId: String = "book"   // Default icon for migration
    
    @Relationship(deleteRule: .cascade) var flashcards: [Flashcard] = []
    @Relationship(deleteRule: .cascade) var questions: [Question] = []
    
    init(title: String, originalText: String, summary: String? = nil, dateCreated: Date = Date(), mode: StudySetMode = .content, iconId: String = "book") {
        self.id = UUID()
        self.title = title
        self.originalText = originalText
        self.summary = summary
        self.dateCreated = dateCreated
        self.mode = mode.rawValue
        self.iconId = iconId
    }
    
    var studySetMode: StudySetMode {
        StudySetMode(rawValue: mode) ?? .content
    }
    
    var icon: StudySetIcon {
        StudySetIcon.icon(for: iconId) ?? StudySetIcon.defaultIcon
    }
}

@Model
final class Flashcard {
    var id: UUID
    var front: String
    var back: String
    var isMastered: Bool
    
    var studySet: StudySet?
    
    init(front: String, back: String, isMastered: Bool = false) {
        self.id = UUID()
        self.front = front
        self.back = back
        self.isMastered = isMastered
    }
}

@Model
final class Question {
    var id: UUID
    var prompt: String
    var answer: String
    var options: [String]? // For multiple choice if needed later
    var explanation: String?
    
    var studySet: StudySet?
    
    init(prompt: String, answer: String, options: [String]? = nil, explanation: String? = nil) {
        self.id = UUID()
        self.prompt = prompt
        self.answer = answer
        self.options = options
        self.explanation = explanation
    }
}
