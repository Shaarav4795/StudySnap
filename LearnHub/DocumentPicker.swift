import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import Vision
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var fileContent: String
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.plainText, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            if url.pathExtension.lowercased() == "pdf" {
                self.parent.fileContent = "Processing PDF..."
                
                DispatchQueue.global(qos: .userInitiated).async {
                    let extractedText = self.extractText(from: url)
                    DispatchQueue.main.async {
                        self.parent.fileContent = extractedText
                    }
                }
            } else {
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    self.parent.fileContent = text
                } catch {
                    print("Error reading file: \(error)")
                    self.parent.fileContent = "Error reading file."
                }
            }
        }
        
        private func extractText(from url: URL) -> String {
            guard let pdfDocument = PDFDocument(url: url) else {
                return "Unable to load PDF."
            }
            
            var fullText = ""
            for i in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: i) {
                    let pageText = page.string ?? ""
                    if !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        fullText += pageText + "\n"
                    } else {
                        fullText += performOCR(on: page) + "\n"
                    }
                }
            }
            return fullText
        }
        
        private func performOCR(on page: PDFPage) -> String {
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: pageRect.size))
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            guard let cgImage = image.cgImage else { return "" }
            
            var extractedText = ""
            let request = VNRecognizeTextRequest { (request, error) in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    extractedText += topCandidate.string + "\n"
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            
            return extractedText
        }
    }
}
