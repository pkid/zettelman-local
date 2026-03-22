import Foundation
import UIKit

enum ExtractionConfidence: String {
    case high
    case guessed
    case missing

    var reviewLabel: String {
        switch self {
        case .high:
            return "Sicher"
        case .guessed:
            return "Pruefen"
        case .missing:
            return "Fehlt"
        }
    }
}

struct ExtractedDateValue {
    let value: Date?
    let hasSpecificTime: Bool
    let confidence: ExtractionConfidence
    let reason: String
}

struct ExtractedTextValue {
    let value: String
    let confidence: ExtractionConfidence
    let reason: String
}

struct ExtractedAppointment {
    let appointmentDate: ExtractedDateValue
    let summary: ExtractedTextValue
    let location: ExtractedTextValue
    let recognizedText: String
}

struct PendingScan: Identifiable {
    let id = UUID()
    let image: UIImage
    let extracted: ExtractedAppointment
}

struct AppointmentDraft {
    let appointmentDate: Date
    let hasSpecificTime: Bool
    let summary: String
    let location: String
}
