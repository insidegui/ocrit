import Foundation

struct TranslationResult {
    var sourceText: String
    var translatedText: String
    var inputLanguage: String
    var outputLanguage: String
}

enum TranslationAvailability {
    /// Translation is supported, but one or more languages are not installed.
    case supported
    /// Translation is supported and all required languages are installed.
    case installed
    /// Translation is not supported.
    case unsupported
}

protocol TranslationOperation {
    static func availability(from inputLanguage: String, to outputLanguage: String) async -> TranslationAvailability
    init(text: String, inputLanguage: String, outputLanguage: String)
    func run() async throws -> TranslationResult
}
