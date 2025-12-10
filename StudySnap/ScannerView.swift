import SwiftUI
import VisionKit
import Vision

struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedText: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: ScannerView
        
        init(_ parent: ScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.presentationMode.wrappedValue.dismiss()
            
            // Process the scanned pages
            let textRecognitionWorkQueue = DispatchQueue(label: "TextRecognitionQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
            
            textRecognitionWorkQueue.async {
                var extractedText = ""
                
                for pageIndex in 0..<scan.pageCount {
                    let image = scan.imageOfPage(at: pageIndex)
                    if let cgImage = image.cgImage {
                        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                        let request = VNRecognizeTextRequest { (request, error) in
                            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                            for observation in observations {
                                guard let topCandidate = observation.topCandidates(1).first else { continue }
                                extractedText += topCandidate.string + "\n"
                            }
                        }
                        request.recognitionLevel = .accurate
                        try? requestHandler.perform([request])
                    }
                }
                
                DispatchQueue.main.async {
                    self.parent.scannedText = extractedText
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.presentationMode.wrappedValue.dismiss()
            print("Document scanner failed: \(error)")
        }
    }
}
