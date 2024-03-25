import Vision
import Quartz

final class PDFOCROperation: OCROperation {

    let documentURL: URL
    let customLanguages: [String]

    init(fileURL: URL, customLanguages: [String]) {
        self.documentURL = fileURL
        self.customLanguages = customLanguages
    }

    func run(fast: Bool) throws -> AsyncThrowingStream<OCRResult, Error> {
        let basename = documentURL.deletingPathExtension().lastPathComponent

        guard let document = CGPDFDocument(documentURL as CFURL) else {
            throw Failure("Failed to read PDF at \(documentURL.path)")
        }

        guard document.numberOfPages > 0 else {
            throw Failure("PDF has no pages at \(documentURL.path)")
        }

        return AsyncThrowingStream { continuation in
            Task {
                for page in (1...document.numberOfPages) {
                    do {
                        let cgImage = try document.cgImage(at: page)

                        let ocr = CGImageOCR(image: cgImage, customLanguages: customLanguages)

                        let text = try await ocr.run(fast: fast)

                        let result = OCRResult(text: text, suggestedFilename: basename + "-\(page)")

                        continuation.yield(result)
                    } catch {
                        /// Don't want to interrupt processing if a single page fails, so don't terminate the stream here.
                        fputs("WARN: Error processing PDF page #\(page) at \(documentURL.path): \(error)\n", stderr)
                    }
                }

                continuation.finish()
            }
        }
    }

}
