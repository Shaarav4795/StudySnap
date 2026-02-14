import SwiftUI
import Foundation

struct MathTextView: View {
    let text: String
    let fontSize: CGFloat
    /// When true, render all non-math segments in bold for emphasis.
    let forceBold: Bool
    @Environment(\.multilineTextAlignment) var textAlignment
    
    init(_ text: String, fontSize: CGFloat = 17, forceBold: Bool = false) {
        self.text = text
        self.fontSize = fontSize
        self.forceBold = forceBold
    }
    
    private var alignment: HorizontalAlignment {
        switch textAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    
    var body: some View {
        // Split by newlines to preserve paragraph structure.
        VStack(alignment: alignment, spacing: 8) {
            ForEach(splitByNewlines(text), id: \.self) { line in
                if #available(iOS 16.0, *) {
                    FlowLayout(spacing: 4, lineSpacing: 4, alignment: alignment) {
                        ForEach(parseMath(line)) { segment in
                            if segment.isMath {
                                MathView(equation: segment.content, fontSize: fontSize + 2)
                                    .fixedSize()
                            } else {
                                Text(segment.content)
                                    .font(.system(size: fontSize))
                                    .fontWeight((forceBold || segment.isBold) ? .bold : .regular)
                                    .italic(segment.isItalic)
                            }
                        }
                    }
                } else {
                    // Fallback for older iOS versions: use a horizontal scroll layout.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(parseMath(line)) { segment in
                                if segment.isMath {
                                    MathView(equation: segment.content, fontSize: fontSize + 2)
                                        .fixedSize()
                                        .padding(.horizontal, 2)
                                } else {
                                    Text(segment.content)
                                        .font(.system(size: fontSize))
                                        .fontWeight((forceBold || segment.isBold) ? .bold : .regular)
                                        .italic(segment.isItalic)
                                }
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
    
    private struct Segment: Identifiable {
        let id = UUID()
        let content: String
        let isMath: Bool
        var isBold: Bool = false
        var isItalic: Bool = false
    }
    
    private func splitByNewlines(_ text: String) -> [String] {
        // Remove empty lines to avoid rendering empty rows.
        return text.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
    
    private func parseMath(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        let components = text.components(separatedBy: "$")
        
        for (index, component) in components.enumerated() {
            if index % 2 == 1 {
                // Math segment between $...$ delimiters.
                if !component.isEmpty {
                    segments.append(Segment(content: component, isMath: true))
                }
            } else {
                // Text segment parsed as Markdown using `AttributedString`.
                if !component.isEmpty {
                    if !containsMarkdownSyntax(component) {
                        let words = component.components(separatedBy: .whitespacesAndNewlines)
                        for word in words where !word.isEmpty {
                            segments.append(Segment(content: word, isMath: false))
                        }
                        continue
                    }
                    do {
                        // Skip segments that are only whitespace.
                        if component.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                             continue 
                        }
                        
                        let attributed = try AttributedString(markdown: component)
                        
                        for run in attributed.runs {
                            let runText = String(attributed[run.range].characters)
                            let isBold = run.inlinePresentationIntent?.contains(.stronglyEmphasized) ?? false
                            let isItalic = run.inlinePresentationIntent?.contains(.emphasized) ?? false
                            
                            // Split run text into words for simple flow layout.
                            let words = runText.components(separatedBy: .whitespaces)
                            for word in words {
                                if !word.isEmpty {
                                    segments.append(Segment(content: word, isMath: false, isBold: isBold, isItalic: isItalic))
                                }
                            }
                        }
                    } catch {
                        // Fallback to plain text tokens if Markdown parsing fails.
                        let words = component.components(separatedBy: .whitespaces)
                        for word in words {
                            if !word.isEmpty {
                                segments.append(Segment(content: word, isMath: false))
                            }
                        }
                    }
                }
            }
        }
        
        return segments
    }

    private func containsMarkdownSyntax(_ value: String) -> Bool {
        value.contains("*") || value.contains("_") || value.contains("#") || value.contains("`") || value.contains("[") || value.contains("]")
    }
}

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func flow(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var points: [CGPoint] = []
        
        // Store items for the current line to center-align vertically.
        struct LineItem {
            let index: Int
            let size: CGSize
            let x: CGFloat
        }
        var currentLineItems: [LineItem] = []
        
        func finalizeLine(items: [LineItem], currentY: CGFloat, lineHeight: CGFloat) {
            let lineWidth = items.last.map { $0.x + $0.size.width } ?? 0
            let xOffset: CGFloat
            
            if maxWidth != .infinity {
                switch alignment {
                case .center:
                    xOffset = (maxWidth - lineWidth) / 2
                case .trailing:
                    xOffset = maxWidth - lineWidth
                default:
                    xOffset = 0
                }
            } else {
                xOffset = 0
            }
            
            for item in items {
                let yOffset = (lineHeight - item.size.height) / 2
                points.append(CGPoint(x: item.x + xOffset, y: currentY + yOffset))
            }
        }
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            // Wrap to a new line when the current line overflows.
            if currentX + size.width > maxWidth && !currentLineItems.isEmpty {
                // Finalize positions for the current line.
                finalizeLine(items: currentLineItems, currentY: currentY, lineHeight: lineHeight)
                
                // Reset state for the next line.
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
                currentLineItems = []
            }
            
            // Add item to the active line.
            currentLineItems.append(LineItem(index: index, size: size, x: currentX))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        // Finalize the last line.
        finalizeLine(items: currentLineItems, currentY: currentY, lineHeight: lineHeight)
        
        return (CGSize(width: maxWidth == .infinity ? currentX : maxWidth, height: currentY + lineHeight), points)
    }
}
