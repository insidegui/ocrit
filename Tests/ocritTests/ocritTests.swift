import XCTest
import class Foundation.Bundle

final class ocritTests: XCTestCase {
    
    

    func testOutputToStdout() throws {
        let input = urlForFixture(named: "test-en.png").path
        
        let (stdout, _) = try runProgram(with: [input])
        
        XCTAssertTrue(stdout.contains("Some text in English"))
    }

    func testLanguageSelectionEnglish() throws {
        let (stdout, _) = try testLanguageSelection(code: "en-US", fixture: "test-en.png")

        XCTAssertTrue(stdout.contains("Some text in English"))
    }
    
    func testLanguageSelectionPortuguese() throws {
        let (stdout, _) = try testLanguageSelection(code: "pt-BR", fixture: "test-pt.png")

        XCTAssertTrue(stdout.contains("Um texto em Português"))
    }
    
    func testLanguageSelectionChinese() throws {
        let (stdout, _) = try testLanguageSelection(code: "zh-Hans", fixture: "test-zh.png")

        XCTAssertTrue(stdout.contains("一些中文文本"))
    }
    
    func testInvalidLanguageExitsWithError() throws {
        let input = urlForFixture(named: "test-en.png").path
        
        let (_, stderr) = try runProgram(with: [
            input,
            "--language",
            "someinvalidlanguage"
        ])
        
        XCTAssertTrue(stderr.contains("Unsupported language"))
    }
    
    func testMultipleImagesOutputToDirectory() throws {
        let outputURL = try getScratchDirectory()
        
        print("[+] Scratch directory for this test case is at \(outputURL.path)")
        
        let expectations = [
            ("test-en.png", "en-US", "test-en.txt", "Some text in English"),
            ("test-pt.png", "pt-BR", "test-pt.txt", "Um texto em Português"),
            ("test-zh.png", "zh-Hans", "test-zh.txt", "一些中文文本")
        ]
        
        for (input, language, filename, text) in expectations {
            try runProgram(with: [
                urlForFixture(named: input).path,
                "--language",
                language,
                "--output",
                outputURL.path
            ])
            
            let outURL = outputURL.appendingPathComponent(filename)
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.path), "Output file for \(language) wasn't written")
            
            let output = try String(contentsOf: outURL, encoding: .utf8)
            
            XCTAssertTrue(output.contains(text), "Output file for \(language) doesn't contain \(text): \(outURL.path)")
        }
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
    }
}

private extension ocritTests {
    
    func testLanguageSelection(code: String, fixture: String) throws -> (String, String) {
        let input = urlForFixture(named: fixture).path
        
        let (stdout, stderr) = try runProgram(with: [
            input,
            "--language",
            code
        ])
        
        XCTAssertTrue(stderr.contains(code), "Should print the selected language to stderr")
        
        return (stdout, stderr)
    }
    
    @discardableResult
    func runProgram(with arguments: [String]) throws -> (String, String) {
        let fooBinary = productsDirectory.appendingPathComponent("ocrit")

        let process = Process()
        process.executableURL = fooBinary
        
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        let errPipe = Pipe()
        process.standardError = errPipe
        
        try process.run()
        process.waitUntilExit()

        let stdout = pipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = errPipe.fileHandleForReading.readDataToEndOfFile()
        
        return (
            String(decoding: stdout, as: UTF8.self),
            String(decoding: stderr, as: UTF8.self)
        )
    }
    
    func urlForFixture(named name: String) -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: "") else {
            XCTFail("Couldn't locate fixture \(name)")
            fatalError()
        }
        
        return url
    }
    
    func getScratchDirectory() throws -> URL {
        let outputDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ocrit_tests_\(UUID())")
        
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        return outputDir
    }
    
}
