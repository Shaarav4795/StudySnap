import SwiftUI
import SwiftMath

struct MathView: UIViewRepresentable {
    let equation: String
    let fontSize: CGFloat
    
    init(equation: String, fontSize: CGFloat = 20) {
        self.equation = equation
        self.fontSize = fontSize
    }
    
    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.textAlignment = .center
        label.fontSize = fontSize
        // labelMode defaults to .math, which is what we want for pure LaTeX segments
        return label
    }
    
    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        uiView.latex = equation
        uiView.fontSize = fontSize
        
        // Adjust color based on environment if needed, but MTMathUILabel defaults to black.
        // Uncomment and use the following if MTMathUILabel supports textColor and you want to use it:
        // if let textColor = UIColor(named: "AccentColor") {
        //     uiView.textColor = textColor
        // }
    }
}
