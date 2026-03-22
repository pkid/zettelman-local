import Foundation
import ImageIO
import UIKit
@preconcurrency import Vision

struct RecognizedLine {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

struct RecognizedText {
    let lines: [RecognizedLine]

    var plainText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

struct TextRecognizer {
    func recognizeText(in image: UIImage) async throws -> RecognizedText {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let preprocessor = OCRImagePreprocessor()
                    let candidates = preprocessor.prepareCandidates(from: image)

                    guard candidates.isEmpty == false else {
                        continuation.resume(throwing: TextRecognizerError.invalidImage)
                        return
                    }

                    let recognizedCandidates = try candidates.compactMap { candidate -> RecognitionCandidate? in
                        let recognizedText = try Self.recognizeText(in: candidate.cgImage)
                        guard recognizedText.lines.isEmpty == false else {
                            return nil
                        }
                        return RecognitionCandidate(
                            text: recognizedText,
                            score: Self.score(for: recognizedText, candidate: candidate)
                        )
                    }

                    guard let bestCandidate = recognizedCandidates.max(by: { lhs, rhs in
                        lhs.score < rhs.score
                    }) else {
                        continuation.resume(throwing: TextRecognizerError.noTextFound)
                        return
                    }

                    continuation.resume(returning: bestCandidate.text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func recognizeText(in cgImage: CGImage) throws -> RecognizedText {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02
        request.recognitionLanguages = ["de-DE", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let observations = request.results ?? []
        let lines = observations
            .compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                return RecognizedLine(
                    text: candidate.string,
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
            }
            .sorted(by: readingOrder)

        return RecognizedText(lines: lines)
    }

    private static func score(for recognizedText: RecognizedText, candidate: OCRPreparedImage) -> Double {
        let plainText = recognizedText.plainText
        let foldedText = plainText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        let totalConfidence = recognizedText.lines.reduce(0.0) { $0 + Double($1.confidence) }
        let keywordHits = ["termin", "datum", "uhr", "praxis", "dr", "labor", "zahnarzt", "frau", "hausarzt"]
            .filter { foldedText.contains($0) }
            .count
        let digitCount = plainText.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count

        var score = totalConfidence * 10.0
        score += Double(recognizedText.lines.count * 3)
        score += Double(keywordHits * 6)
        score += Double(digitCount) * 0.08
        if candidate.wasCropped {
            score += 1.2
        }
        return score
    }

    private static func readingOrder(lhs: RecognizedLine, rhs: RecognizedLine) -> Bool {
        let verticalDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
        if verticalDistance > 0.035 {
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }

        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}

enum TextRecognizerError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected image could not be processed."
        case .noTextFound:
            return "No readable text was found on this note."
        }
    }
}

private struct RecognitionCandidate {
    let text: RecognizedText
    let score: Double
}
