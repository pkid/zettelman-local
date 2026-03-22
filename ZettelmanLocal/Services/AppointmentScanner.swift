import UIKit

@MainActor
struct AppointmentScanner {
    private let textRecognizer = TextRecognizer()
    private let extractor = AppointmentExtractor()

    func scan(image: UIImage) async throws -> ExtractedAppointment {
        let recognizedText = try await textRecognizer.recognizeText(in: image)
        return extractor.extract(from: recognizedText)
    }
}
