import Foundation
import ArgumentParser
import UniformTypeIdentifiers

struct Failure: LocalizedError {
    var errorDescription: String?
    init(_ desc: String) { self.errorDescription = desc }
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
        if !shouldOutputToStdout {
            guard URL(fileURLWithPath: output).isExistingDirectory else {
                throw Failure("Output path doesn't exist (or is not a directory) at \(output)")
            }
        }
        
        let imageURLs = imagePaths.map(URL.init(fileUrlWithTildePath:))
        
        fputs("Validating images…\n", stderr)
        
        do {
            for url in imageURLs {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw Failure("Image doesn't exist at \(url.path)")
                }
                
                guard let type = (try url.resourceValues(forKeys: [.contentTypeKey])).contentType else {
                    throw Failure("Unable to determine file type at \(url.path)")
                }
                
                guard type.conforms(to: .image) else {
                    throw Failure("File at \(url.path) is not an image")
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
            let operation = OCROperation(imageURL: url, customLanguages: language)
            
            do {
                let text = try await operation.run()
                
                try writeOutput(text, for: url)
            } catch {
                fputs("OCR failed for \(url.lastPathComponent): \(error.localizedDescription)\n", stderr)
            }
        }
    }
    
    private func writeOutput(_ text: String, for imageURL: URL) throws {
        guard output != "-" else {
            print(imageURL.lastPathComponent + ":")
            print(text + "\n")
            return
        }
        
        var outputURL = URL(fileURLWithPath: output)
            .appendingPathComponent(imageURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("txt")
        
        try text.write(to: outputURL, atomically: true, encoding: .utf8)
        
        if let attributes = try? imageURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        {
            try outputURL.setResourceValues(attributes)
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
