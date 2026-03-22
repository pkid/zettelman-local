import XCTest
@testable import ZettelmanLocal

final class AppointmentExtractorFixtureTests: XCTestCase {
    private let extractor = AppointmentExtractor()
    private let calendar = Calendar(identifier: .gregorian)

    func testOrthomolCardFixture() {
        let extracted = extractor.extract(
            from: recognizedText([
                "orthomol",
                "Ihre nächsten Termine",
                "Wochentag, Datum, Uhrzeit",
                "Mo. 14.09.26 8:30uhr",
                "Dr. med. Kristine Spatzier",
                "Fachärztin für Frauenheilkunde u. Geburtshilfe",
                "Schwetzinger Str. 17, 69124 Heidelberg"
            ]),
            referenceDate: referenceDate()
        )

        assertDate(extracted.appointmentDate.value, year: 2026, month: 9, day: 14, hour: 8, minute: 30)
        XCTAssertTrue(extracted.appointmentDate.hasSpecificTime)
        XCTAssertEqual(extracted.summary.value, "Frauenarzttermin")
        XCTAssertTrue(extracted.location.value.contains("Kristine Spatzier"))
    }

    func testStructuredLaborFixture() {
        let extracted = extractor.extract(
            from: recognizedText([
                "Termine",
                "gedruckt am: 17.03.2026",
                "Datum",
                "Uhrzeit Bereich",
                "Fr. 27.03.26",
                "08:30",
                "Labor",
                "Praxis Dr. med. H. Mittnacht",
                "Hausarzt und Internist"
            ]),
            referenceDate: referenceDate()
        )

        assertDate(extracted.appointmentDate.value, year: 2026, month: 3, day: 27, hour: 8, minute: 30)
        XCTAssertTrue(extracted.appointmentDate.hasSpecificTime)
        XCTAssertEqual(extracted.summary.value, "Labor")
        XCTAssertTrue(extracted.location.value.contains("Mittnacht"))
    }

    func testDentalCardFixture() {
        let extracted = extractor.extract(
            from: recognizedText([
                "Zahnarztpraxis Samir Youssef",
                "Ihr nächster Termin bei uns:",
                "Datum",
                "Uhrzeit",
                "19.32611:15",
                "Marktstraße 65 | 68789 St. Leon-Rot"
            ]),
            referenceDate: referenceDate()
        )

        assertDate(extracted.appointmentDate.value, year: 2026, month: 3, day: 19, hour: 11, minute: 15)
        XCTAssertTrue(extracted.appointmentDate.hasSpecificTime)
        XCTAssertEqual(extracted.summary.value, "Zahnarzttermin")
        XCTAssertTrue(extracted.location.value.contains("Samir Youssef"))
    }

    func testPhysioHeaderFallsBackToPhysiotherapySummary() {
        let extracted = extractor.extract(
            from: recognizedText([
                "Fit & Fun physio und fitness",
                "Opelstr. 2",
                "68789 St. Leon-Rot",
                "02.02.26"
            ]),
            referenceDate: referenceDate()
        )

        XCTAssertEqual(extracted.summary.value, "Physiotherapietermin")
        XCTAssertTrue(extracted.location.value.contains("Fit & Fun"))
    }

    private func recognizedText(_ lines: [String]) -> RecognizedText {
        let recognizedLines = lines.enumerated().map { index, line in
            RecognizedLine(
                text: line,
                boundingBox: CGRect(x: 0.0, y: 1.0 - (Double(index) * 0.06), width: 1.0, height: 0.04),
                confidence: 1.0
            )
        }
        return RecognizedText(lines: recognizedLines)
    }

    private func referenceDate() -> Date {
        let components = DateComponents(calendar: calendar, year: 2026, month: 3, day: 17, hour: 12, minute: 0)
        return calendar.date(from: components) ?? .now
    }

    private func assertDate(_ date: Date?, year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        XCTAssertNotNil(date)
        guard let date else { return }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        XCTAssertEqual(components.year, year)
        XCTAssertEqual(components.month, month)
        XCTAssertEqual(components.day, day)
        XCTAssertEqual(components.hour, hour)
        XCTAssertEqual(components.minute, minute)
    }
}
