import Foundation
import ArgumentParser
import UniformTypeIdentifiers
import class Vision.VNRecognizeTextRequest
import PathKit

struct Failure: LocalizedError, CustomStringConvertible {
    var errorDescription: String?
    init(_ desc: String) { self.errorDescription = desc }
    var description: String { errorDescription ?? "" }
}

@main
struct ocrit: AsyncParsableCommand {
    
    @Argument(help: "Path or list of paths for the images")
    var imagePaths: [Path]

    @Option(
        name: .shortAndLong, help: "Path to a directory where the txt files will be written to, or - for standard output"
    )
    var output: Output = .stdOutput

    @Option(name: .shortAndLong, help: "Language code to use for the recognition, can be repeated to select multiple languages")
    var language: [String] = []

    @Flag(name: .shortAndLong, help: "Uses an OCR algorithm that prioritizes speed over accuracy")
    var fast = false


    func validate() throws {
        if let path = output.path, !path.isDirectory {
            do {
                try path.mkdir()
            } catch {
                throw ValidationError("Output path doesn't exist or is not a directory, and a directory couldn't be created at \(output). \(error)")
            }
        }

        /// Validate languages before attempting any OCR operations so that we can exit early in case there's an unsupported language.
        try VNRecognizeTextRequest.validateLanguages(with: language)
    }

    func run() async throws {
        let imageURLs = imagePaths.map(\.url)

        fputs("Validating images…\n", stderr)

        var operationType: OCROperation.Type = ImageOCROperation.self

        do {
            for url in imageURLs {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw Failure("Image doesn't exist at \(url.path)")
                }
                
                guard let type = (try url.resourceValues(forKeys: [.contentTypeKey])).contentType else {
                    throw Failure("Unable to determine file type at \(url.path)")
                }
                
                if type.conforms(to: .image) {
                    operationType = ImageOCROperation.self
                } else if type.conforms(to: .pdf) {
                    operationType = PDFOCROperation.self
                } else {
                    throw Failure("File type at \(url.path) is not supported: \(type.identifier)")
                }
            }
        } catch {
            fputs("WARN: \(error.localizedDescription)\n", stderr)
        }
        
        if language.isEmpty {
            fputs("Performing OCR…\n", stderr)
        } else {
            if language.count == 1 {
                fputs("Performing OCR with language: \(language[0])…\n", stderr)
            } else {
                fputs("Performing OCR with languages: \(language.joined(separator: ", "))…\n", stderr)
            }
        }
        
        for url in imageURLs {
            let operation = operationType.init(fileURL: url, customLanguages: language)

            do {
                for try await result in try operation.run(fast: fast) {
                    try writeResult(result, for: url)
                }
            } catch {
                /// Exit with error if there's only one image, otherwise we won't interrupt execution and will keep trying the other ones.
                guard imageURLs.count > 1 else {
                    throw error
                }

                fputs("OCR failed for \(url.lastPathComponent): \(error.localizedDescription)\n", stderr)
            }
        }
    }
    
    private func writeResult(_ result: OCRResult, for imageURL: URL) throws {
        guard let outputDirectoryURL = output.path?.url else {
            print(imageURL.lastPathComponent + ":")
            print(result.text + "\n")
            return
        }
        
        var outputFileURL = outputDirectoryURL
            .appendingPathComponent(result.suggestedFilename)
            .appendingPathExtension("txt")
        
        try result.text.write(to: outputFileURL, atomically: true, encoding: .utf8)

        if let attributes = try? imageURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        {
            try outputFileURL.setResourceValues(attributes)
        }
    }
}
