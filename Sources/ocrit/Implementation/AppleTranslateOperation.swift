import Foundation
private import Translation
private import SwiftUI

@available(macOS 15.0, *)
struct AppleTranslateOperation: TranslationOperation {
    let text: String
    let inputLanguage: String
    let outputLanguage: String

    func run() async throws -> TranslationResult {
        let translator = Translator(sourceLanguage: inputLanguage, targetLanguage: outputLanguage)

        let response = try await translator.run(text)

        return TranslationResult(
            sourceText: text,
            translatedText: response.targetText,
            inputLanguage: inputLanguage,
            outputLanguage: outputLanguage
        )
    }

    static func availability(from inputLanguage: String, to outputLanguage: String) async -> TranslationAvailability {
        let availability = LanguageAvailability()
        let status = await availability.status(from: .init(identifier: inputLanguage), to: .init(identifier: outputLanguage))

        return switch status {
        case .supported: .supported
        case .installed: .installed
        case .unsupported: .unsupported
        @unknown default: .unsupported
        }
    }
}

// MARK: - Translation Shenanigans

/**
 So, here's the thing: Translation was REALLY not meant to be run outside of an app's user interface,
 but I also REALLY wanted this capability in OCRIT, so I did what I had to do. Don't judge me.
 */
@available(macOS 15.0, *)
@MainActor
private struct Translator {
    let sourceLanguage: String
    let targetLanguage: String

    private struct _UIShim: View {
        var sourceLanguage: String
        var targetLanguage: String
        var text: String
        var callback: (Result<TranslationSession.Response, Error>) -> ()

        var body: some View {
            EmptyView()
                .translationTask(source: .init(identifier: sourceLanguage), target: .init(identifier: targetLanguage)) { session in
                    do {
                        let result = try await session.translate(text)
                        callback(.success(result))
                    } catch {
                        callback(.failure(error))
                    }
                }
        }
    }

    func run(_ text: String) async throws -> TranslationSession.Response {
        try await withCheckedThrowingContinuation { continuation in
            let shim = _UIShim(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, text: text) {
                continuation.resume(with: $0)
            }

            /// This somehow works when running from a SPM-based executable...
            let window = NSWindow(contentViewController: NSHostingController(rootView: shim))
            window.setFrame(.zero, display: false)
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@available(macOS 15.0, *)
extension TranslationSession: @retroactive @unchecked Sendable { }
