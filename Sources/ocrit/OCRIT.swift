import Foundation
import ArgumentParser
import UniformTypeIdentifiers
import class Vision.VNRecognizeTextRequest

struct Failure: LocalizedError, CustomStringConvertible {
    var errorDescription: String?
    init(_ desc: String) { self.errorDescription = desc }
    var description: String { errorDescription ?? "" }
}

@main
struct ocrit: AsyncParsableCommand {
    
    @Argument(help: "Path or list of paths for the images")
    var imagePaths: [String]
    
    @Option(name: .shortAndLong, help: "Path to a directory where the txt files will be written to, or - for standard output")
    var output: String = "-"
    
    @Option(name: .shortAndLong, help: "Language code to use for the recognition, can be repeated to select multiple languages")
    var language: [String] = []

    private var shouldOutputToStdout: Bool { output == "-" }

    func run() async throws {
        let outputDirectoryURL = URL(fileUrlWithTildePath: output)

        if !shouldOutputToStdout {
            guard outputDirectoryURL.isExistingDirectory else {
                throw Failure("Output path doesn't exist (or is not a directory) at \(output)")
            }
        }

        /// Validate languages before attempting any OCR operations so that we can exit early in case there's an unsupported language.
        try VNRecognizeTextRequest.validateLanguages(with: language)

        let imageURLs = imagePaths.map(URL.init(fileUrlWithTildePath:))
        
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
                for try await result in try operation.run() {
                    try writeResult(result, for: url, outputDirectoryURL: outputDirectoryURL)
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
    
    private func writeResult(_ result: OCRResult, for imageURL: URL, outputDirectoryURL: URL) throws {
        guard !shouldOutputToStdout else {
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

extension URL {
    var isExistingDirectory: Bool {
        var dirCheck = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &dirCheck) else { return false }
        return dirCheck.boolValue
    }
    
    init(fileUrlWithTildePath: String) {
        let tildeExpanded = fileUrlWithTildePath.exapnadingTildeInPath
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        self.init(fileURLWithPath: tildeExpanded, relativeTo: currentDirectory)
    }
}

extension String {
    var exapnadingTildeInPath: String {
        let ns = NSString(string: self)
        let expanded = ns.expandingTildeInPath
        return String(expanded)
    }
}
