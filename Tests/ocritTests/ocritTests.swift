import XCTest
import class Foundation.Bundle
import ArgumentParser

final class OCRITTests: XCTestCase {

    func testOutputToStdout() throws {
        let input = fixturePath(named: "test-en.png")

        try AssertExecuteCommand(
            command: "ocrit \(input)",
            expected: .stdout(.equal("test-en.png:\nSome text in English")),
            exitCode: .success
        )
    }

    func testLanguageSelectionEnglish() throws {
        let input = fixturePath(named: "test-en.png")

        try AssertExecuteCommand(
            command: "ocrit \(input) --language en-US",
            expected: [
                .stderr(.contain("en-US")), /// should print selected language to stderr
                .stdout(.contain("Some text in English")) /// should print correct OCR result to stdout
            ],
            exitCode: .success
        )
    }
    
    func testLanguageSelectionPortuguese() throws {
        let input = fixturePath(named: "test-pt.png")

        try AssertExecuteCommand(
            command: "ocrit \(input) --language pt-BR",
            expected: [
                .stderr(.contain("pt-BR")), /// should print selected language to stderr
                .stdout(.contain("Um texto em Português")) /// should print correct OCR result to stdout
            ],
            exitCode: .success
        )
    }
    
    func testLanguageSelectionChinese() throws {
        let input = fixturePath(named: "test-zh.png")

        try AssertExecuteCommand(
            command: "ocrit \(input) --language zh-Hans",
            expected: [
                .stderr(.contain("zh-Hans")), /// should print selected language to stderr
                .stdout(.contain("一些中文文本")) /// should print correct OCR result to stdout
            ],
            exitCode: .success
        )
    }

    func testMultipleLanguages() throws {
        let input = fixturePath(named: "test-multi-en-ko.png")

        try AssertExecuteCommand(
            command: "ocrit \(input) -l ko-KR -l en-US",
            expected: [
                .stdout(.contain("like turtles")),
                .stdout(.contain("나는 거북이를 좋아한다")),
            ],
            exitCode: .success
        )
    }

    func testInvalidLanguageExitsWithError() throws {
        let input = fixturePath(named: "test-en.png")
        
        try AssertExecuteCommand(
            command: "ocrit \(input) --language someinvalidlanguage",
            expected: .stderr(.contain("Unsupported language")),
            exitCode: .validationFailure
        )
    }

    func testSpeedOverAccuracy() throws {
        let input = fixturePath(named: "test-en.png")

        try AssertExecuteCommand(
            command: "ocrit \(input) --fast",
            expected: .stdout(.equal("test-en.png:\nSome text in English")),
            exitCode: .success
        )
    }

    func testMultipleImagesOutputToDirectory() throws {
        let outputURL = try getScratchDirectory()
        
        print("[+] Scratch directory for this test case is at \(outputURL.path)")
        
        let expectations = [
            ("test-en.png", "en-US", "test-en.txt", "Some text in English"),
            ("test-pt.png", "pt-BR", "test-pt.txt", "Um texto em Português"),
            ("test-zh.png", "zh-Hans", "test-zh.txt", "一些中文文本")
        ]
        
        for (inputFilename, language, outputFilename, text) in expectations {
            let input = fixturePath(named: inputFilename)

            try AssertExecuteCommand(
                command: "ocrit \(input) --language \(language) --output \(outputURL.path)",
                exitCode: .success
            )

            let outURL = outputURL.appendingPathComponent(outputFilename)

            XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.path), "Output file for \(language) wasn't written")
            
            let output = try String(contentsOf: outURL, encoding: .utf8)
            
            XCTAssertTrue(output.contains(text), "Output file for \(language) doesn't contain \(text): \(outURL.path)")
        }
    }

    func testSinglePagePDFOutputToStdout() throws {
        let input = fixturePath(named: "test-en-singlepage.pdf")

        try AssertExecuteCommand(
            command: "ocrit \(input)",
            expected: .stdout(.contain("You can update your iPhone to iOS 17.4.1 by heading to the Settings app")),
            exitCode: .success
        )
    }

    func testMultipagePDFOutputToStdout() throws {
        let input = fixturePath(named: "test-en-multipage.pdf")

        try AssertExecuteCommand(
            command: "ocrit \(input)",
            expected: [
                .stdout(.contain("You can update your iPhone to iOS 17.4.1 by heading to the Settings app")), /// From page 1
                .stdout(.contain("When you add a resource to your Swift package, Xcode detects common resource types")), /// From page 2
                .stdout(.contain("To add a resource that Xcode can't handle automatically")), /// From page 3
            ],
            exitCode: .success
        )
    }

    func testMultipagePDFOutputToDirectory() throws {
        let outputURL = try getScratchDirectory()

        print("[+] Scratch directory for this test case is at \(outputURL.path)")

        let expectations = [
            ("test-en-multipage-1.txt", "You can update your iPhone to iOS 17.4.1 by heading to the Settings app"),
            ("test-en-multipage-2.txt", "When you add a resource to your Swift package, Xcode detects common resource types"),
            ("test-en-multipage-3.txt", "To add a resource that Xcode can't handle automatically"),
        ]

        let input = fixturePath(named: "test-en-multipage.pdf")

        try AssertExecuteCommand(
            command: "ocrit \(input) --output \(outputURL.path)",
            exitCode: .success
        )

        for (outputFilename, text) in expectations {
            let outURL = outputURL.appendingPathComponent(outputFilename)

            XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.path), "Output file \(outputFilename) wasn't written")

            let output = try String(contentsOf: outURL, encoding: .utf8)

            XCTAssertTrue(output.localizedCaseInsensitiveContains(text), "Output file \(outputFilename) doesn't contain \(text): \(outURL.path)")
        }
    }
}

private extension OCRITTests {
    func fixturePath(named name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "") else {
            XCTFail("Couldn't locate fixture \(name)")
            fatalError()
        }
        
        return url.path
    }
    
    func getScratchDirectory() throws -> URL {
        let outputDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ocrit_tests_\(UUID())")
        
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        return outputDir
    }
    
}

extension String {
    var quoted: String { "\"\(self)\"" }
}
