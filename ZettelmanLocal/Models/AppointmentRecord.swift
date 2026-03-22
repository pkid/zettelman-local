import Foundation
import SwiftData

@Model
final class AppointmentRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var appointmentDate: Date
    var hasSpecificTime: Bool
    var summaryText: String
    var locationText: String
    var imageFilename: String
    var recognizedText: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        appointmentDate: Date,
        hasSpecificTime: Bool,
        summaryText: String,
        locationText: String,
        imageFilename: String,
        recognizedText: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.appointmentDate = appointmentDate
        self.hasSpecificTime = hasSpecificTime
        self.summaryText = summaryText
        self.locationText = locationText
        self.imageFilename = imageFilename
        self.recognizedText = recognizedText
    }
}
