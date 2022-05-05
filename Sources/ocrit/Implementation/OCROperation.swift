import Vision
import Cocoa

final class OCROperation {
    
    let imageURL: URL
    let customLanguages: [String]
    
    init(imageURL: URL, customLanguages: [String]) {
        self.imageURL = imageURL
        self.customLanguages = customLanguages
    }
    
    private var request: VNRecognizeTextRequest?
    private var handler: VNImageRequestHandler?
    
    func run() async throws -> String {
        guard let image = NSImage(contentsOf: imageURL) else {
            throw Failure("Couldn't read image at \(imageURL.path)")
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Failure("Couldn't read CGImage fir \(imageURL.lastPathComponent)")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) -> Void in
            performRequest(with: cgImage) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(throwing: Failure("No results"))
                        return
                    }
                    
                    var transcript: String = ""
                    for observation in observations {
                        transcript.append(observation.topCandidates(1)[0].string)
                        transcript.append("\n")
                    }

                    continuation.resume(with: .success(transcript))
                }
            }
        }
    }
    
    private func performRequest(with image: CGImage, completion: @escaping VNRequestCompletionHandler) {
        let newHandler = VNImageRequestHandler(cgImage: image)
        
        let newRequest = VNRecognizeTextRequest(completionHandler: completion)
        newRequest.recognitionLevel = .accurate
        
        do {
            if let customLanguages = try resolveLanguages(for: newRequest) {
                newRequest.recognitionLanguages = customLanguages
            }
        } catch {
            completion(newRequest, error)
            return
        }

        request = newRequest
        handler = newHandler
        
        do {
            try newHandler.perform([newRequest])
        } catch {
            completion(newRequest, error)
        }
    }
    
    private func resolveLanguages(for request: VNRecognizeTextRequest) throws -> [String]? {
        guard !customLanguages.isEmpty else { return nil }
        
        let supportedLanguages = try request.supportedRecognitionLanguages()
        
        for customLanguage in customLanguages {
            guard supportedLanguages.contains(customLanguage) else {
                throw Failure("Unsupported language \"\(customLanguage)\". Supported languages are \(supportedLanguages.joined(separator: ", "))")
            }
        }
        
        return customLanguages
    }
    
}
