import Foundation

struct OCRResult {
    var text: String
    var suggestedFilename: String
}

protocol OCROperation {
    init(fileURL: URL, customLanguages: [String])
    func run(fast: Bool) throws -> AsyncThrowingStream<OCRResult, Error>
}
