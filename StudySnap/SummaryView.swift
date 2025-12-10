import SwiftUI

struct SummaryView: View {
    let summary: String
    var isGuide: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: isGuide ? "book.fill" : "text.alignleft")
                        .foregroundColor(.accentColor)
                    Text(isGuide ? "Learning Guide" : "Summary")
                        .font(.title2)
                        .bold()
                }
                .padding(.bottom, 8)
                
                // Removed AI-generated caption per user request
                
                if isBulletPoints(summary) {
                    let bullets = parseBulletPoints(summary)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(bullets, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 8)

                                MathTextView(point, fontSize: 17)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                } else {
                    MathTextView(summary, fontSize: 17)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    private func isBulletPoints(_ text: String) -> Bool {
        let rawLines = text.components(separatedBy: .newlines)
        let nonEmptyLines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard nonEmptyLines.count >= 2 else { return false }

        var markerCount = 0
        for line in nonEmptyLines {
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                markerCount += 1
            } else if let _ = line.range(of: "^\\d+\\. ", options: .regularExpression) {
                markerCount += 1
            }
        }

        // Treat as a bullet list when at least one line uses an explicit list marker
        return markerCount >= 1
    }
    
    private func parseBulletPoints(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var results: [String] = []

        var currentItem: String? = nil

        func finishCurrent() {
            if let item = currentItem?.trimmingCharacters(in: .whitespacesAndNewlines), !item.isEmpty {
                results.append(item)
            }
            currentItem = nil
        }

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("- ") {
                finishCurrent()
                currentItem = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("* ") {
                finishCurrent()
                currentItem = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("• ") {
                finishCurrent()
                currentItem = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let match = trimmed.range(of: "^\\d+\\. ", options: .regularExpression) {
                finishCurrent()
                let after = trimmed[match.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                currentItem = String(after)
            } else {
                // Continuation line: usually a wrapped bullet. Append to current if it exists.
                if currentItem != nil {
                    currentItem = (currentItem! + " " + trimmed)
                } else {
                    // No current bullet — start a new one from this line
                    currentItem = trimmed
                }
            }
        }

        finishCurrent()

        return results
    }
}
