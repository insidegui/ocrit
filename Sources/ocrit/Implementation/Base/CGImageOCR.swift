import Vision
import Cocoa

final class CGImageOCR {

    let image: CGImage
    let customLanguages: [String]

    init(image: CGImage, customLanguages: [String]) {
        self.image = image
        self.customLanguages = customLanguages
    }

    private var request: VNRecognizeTextRequest?
    private var handler: VNImageRequestHandler?

    func run() async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) -> Void in
            performRequest(with: image) { request, error in
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

    func performRequest(with image: CGImage, completion: @escaping VNRequestCompletionHandler) {
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
        try request.validateLanguages(with: customLanguages)
    }

}

extension VNRecognizeTextRequest {
    @discardableResult
    static func validateLanguages(with customLanguages: [String]) throws -> [String]? {
        let dummy = VNRecognizeTextRequest()
        return try dummy.validateLanguages(with: customLanguages)
    }

    fileprivate func validateLanguages(with customLanguages: [String]) throws -> [String]? {
        guard !customLanguages.isEmpty else { return nil }

        let supportedLanguages = try supportedRecognitionLanguages()

        for customLanguage in customLanguages {
            guard supportedLanguages.contains(customLanguage) else {
                throw Failure("Unsupported language \"\(customLanguage)\". Supported languages are: \(supportedLanguages.joined(separator: ", "))")
            }
        }

        return customLanguages
    }
}
