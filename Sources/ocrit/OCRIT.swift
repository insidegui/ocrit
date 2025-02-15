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

    @Option(name: [.customShort("t"), .customLong("translate")], help: """
    Language code to translate the detected text into. Requires macOS 15 or later.
    
    When using this option, the source language must be specified with -l/--language.
    
    ⚠️ This feature is experimental, use at your own risk.
    """)
    var translateIntoLanguageCode: String?

    @Flag(name: .shortAndLong, help: """
    When -t/--translate is used, delete the original text files and only keep the translated ones.
    
    Also omits printing original untranslated text when output is stdout. 
    """)
    var deleteOriginals = false

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

        guard translateIntoLanguageCode != nil else { return }

        guard #available(macOS 15.0, *) else {
            throw ValidationError("Translation is only available in macOS 15 or later.")
        }
        guard !language.isEmpty else {
            throw ValidationError("When using -t/--translate, the language of the document must be specified with -l/--language.")
        }
        guard language.count == 1 else {
            throw ValidationError("When using -t/--translate, only a single language can be specified with -l/--language.")
        }
    }

    private func checkTranslationAvailability() async throws {
        guard #available(macOS 15.0, *) else { return }
        guard let translateIntoLanguageCode else { return }

        let availability = await AppleTranslateOperation.availability(from: language[0], to: translateIntoLanguageCode)

        switch availability {
        case .supported:
            throw ValidationError("Translation is not supported from \"\(language[0])\" to \"\(translateIntoLanguageCode)\".")
        case .installed:
            break
        case .unsupported:
            throw ValidationError("""
            In order to translate from \"\(language[0])\" to \"\(translateIntoLanguageCode)\", language support must be installed on your system.
            
            Go to System Settings > Language & Region > Translation Languages to install the languages.
            """)
        }
    }

    func run() async throws {
        try await checkTranslationAvailability()
        
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
            let fileAttributes = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])

            do {
                for try await result in try operation.run(fast: fast) {
                    let translation = await runTranslationIfNeeded(for: result)

                    try await processResult(
                        result,
                        translation: translation,
                        for: url,
                        fileAttributes: fileAttributes
                    )
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

    private func runTranslationIfNeeded(for result: OCRResult) async -> TranslationResult? {
        guard #available(macOS 15.0, *) else { return nil }
        guard let translateIntoLanguageCode else { return nil }

        do {
            let operation = AppleTranslateOperation(
                text: result.text,
                inputLanguage: language[0],
                outputLanguage: translateIntoLanguageCode
            )

            let result = try await operation.run()

            return result
        } catch {
            fputs("WARN: Translation failed for \"\(result.suggestedFilename)\". \(error)", stderr)
            return nil
        }
    }

    private func processResult(_ result: OCRResult, translation: TranslationResult?, for imageURL: URL, fileAttributes: URLResourceValues?) async throws {
        guard let outputDirectoryURL = output.path?.url else {
            writeStandardOutput(for: result, translation: translation, imageURL: imageURL)
            return
        }
        
        let outputFileURL = outputDirectoryURL
            .appendingPathComponent(result.suggestedFilename)
            .appendingPathExtension("txt")
        
        try result.text.write(to: outputFileURL, atomically: true, encoding: .utf8)

        outputFileURL.mergeAttributes(fileAttributes)

        guard let translation else { return }

        let translatedFilename = outputFileURL
            .deletingPathExtension()
            .lastPathComponent + "_\(translation.outputLanguage)"

        let translatedURL = outputFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(translatedFilename, conformingTo: .plainText)

        try translation.translatedText.write(
            to: translatedURL,
            atomically: true,
            encoding: .utf8
        )

        translatedURL.mergeAttributes(fileAttributes)

        outputFileURL.deleteIfNeeded(deleteOriginals)
    }

    private func writeStandardOutput(for result: OCRResult, translation: TranslationResult?, imageURL: URL) {
        if let translation {
            /// Don't print out original untranslated OCR if -d is specified.
            if !deleteOriginals {
                print("\(imageURL.lastPathComponent) (\(translation.inputLanguage))" + ":")
                print(result.text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n")
            }

            print("\(imageURL.lastPathComponent) (\(translation.outputLanguage))" + ":")
            print(translation.translatedText.trimmingCharacters(in: .whitespacesAndNewlines) + "\n")
        } else {
            print(imageURL.lastPathComponent + ":")
            print(result.text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n")
        }
    }
}

// MARK: - Helpers

private extension URL {
    /// We don't want the entire OCR operation to fail if the tool can't copy file attributes from the image into the OCRed txt.
    /// This function attempts to merge the attributes and just logs to stderr if that fails.
    func mergeAttributes(_ values: URLResourceValues?) {
        guard let values else { return }

        var mSelf = self

        do {
            try mSelf.setResourceValues(values)
        } catch {
            fputs("WARN: Failed to set file attributes for \"\(lastPathComponent)\". \(error)\n", stderr)
        }
    }

    /// Syntactic sugar for conditionally deleting a file with a non-fatal error.
    func deleteIfNeeded(_ delete: Bool) {
        guard delete else { return }

        do {
            try FileManager.default.removeItem(at: self)
        } catch {
            fputs("WARN: Failed to delete \"\(lastPathComponent)\". \(error)\n", stderr)
        }
    }
}
