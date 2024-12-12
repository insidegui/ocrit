import ArgumentParser
import Vision

extension VNRecognizeTextRequest {
    @discardableResult
    static func validateLanguages(with customLanguages: [String]) throws -> [String]? {
        let dummy = VNRecognizeTextRequest()
        return try dummy.validateLanguages(with: customLanguages)
    }

    func validateLanguages(with customLanguages: [String]) throws -> [String]? {
        guard !customLanguages.isEmpty else { return nil }

        let supportedLanguages = try supportedRecognitionLanguages()

        for customLanguage in customLanguages {
            guard supportedLanguages.contains(customLanguage) else {
                throw ValidationError("Unsupported language \"\(customLanguage)\". Supported languages are: \(supportedLanguages.joined(separator: ", "))")
            }
        }

        return customLanguages
    }
}
