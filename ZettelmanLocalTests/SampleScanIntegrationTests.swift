import XCTest
import UIKit
@testable import ZettelmanLocal

final class SampleScanIntegrationTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testIMG6829Sample() async throws {
        try await assertSample(named: "IMG_6829")
    }

    func testIMG6830Sample() async throws {
        try await assertSample(named: "IMG_6830")
    }

    func testIMG6831Sample() async throws {
        try await assertSample(named: "IMG_6831")
    }

    func testIMG6832Sample() async throws {
        try await assertSample(named: "IMG_6832")
    }

    private func assertSample(named name: String) async throws {
        let expectation = try loadExpectations().first(where: { sample in sample.name == name })
        guard let expectation else {
            XCTFail("Missing expectation for \(name)")
            return
        }

        let imageURL = localSampleDirectory().appendingPathComponent(expectation.filename)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw XCTSkip("Local sample missing at \(imageURL.path)")
        }
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            XCTFail("Could not load sample image at \(imageURL.path)")
            return
        }

        let extracted = try await AppointmentScanner().scan(image: image)
        assertDate(extracted.appointmentDate.value, sample: expectation)
        XCTAssertEqual(extracted.appointmentDate.hasSpecificTime, expectation.hasSpecificTime)
        XCTAssertEqual(extracted.summary.value, expectation.summary)

        let loweredLocation = extracted.location.value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        for token in expectation.locationContains {
            XCTAssertTrue(
                locationLooselyContains(token, in: loweredLocation),
                "Expected location to contain \(token), got: \(extracted.location.value)"
            )
        }
    }

    private func loadExpectations() throws -> [SampleExpectation] {
        let url = repositoryRoot().appendingPathComponent("Evaluation/sample_expectations.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SampleExpectation].self, from: data)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func localSampleDirectory() -> URL {
        repositoryRoot().appendingPathComponent("Evaluation/.local-samples")
    }

    private func assertDate(_ date: Date?, sample: SampleExpectation) {
        XCTAssertNotNil(date)
        guard let date else { return }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        XCTAssertEqual(components.year, sample.year)
        XCTAssertEqual(components.month, sample.month)
        XCTAssertEqual(components.day, sample.day)
        XCTAssertEqual(components.hour, sample.hour)
        XCTAssertEqual(components.minute, sample.minute)
    }

    private func locationLooselyContains(_ token: String, in location: String) -> Bool {
        let normalizedToken = normalizedComparable(token)
        let normalizedLocation = normalizedComparable(location)

        if normalizedLocation.contains(normalizedToken) {
            return true
        }

        let tokenWords = normalizedToken.split(separator: " ").map(String.init)
        let locationWords = normalizedLocation.split(separator: " ").map(String.init)

        if tokenWords.count == 1 {
            return locationWords.contains { word in
                levenshteinDistance(between: word, and: normalizedToken) <= 1
            }
        }

        return false
    }

    private func normalizedComparable(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func levenshteinDistance(between lhs: String, and rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        var distances = Array(0...rhsChars.count)
        for (lhsIndex, lhsChar) in lhsChars.enumerated() {
            var previousDistance = distances[0]
            distances[0] = lhsIndex + 1

            for (rhsIndex, rhsChar) in rhsChars.enumerated() {
                let currentDistance = distances[rhsIndex + 1]
                if lhsChar == rhsChar {
                    distances[rhsIndex + 1] = previousDistance
                } else {
                    distances[rhsIndex + 1] = min(
                        distances[rhsIndex] + 1,
                        currentDistance + 1,
                        previousDistance + 1
                    )
                }
                previousDistance = currentDistance
            }
        }

        return distances[rhsChars.count]
    }
}

private struct SampleExpectation: Decodable {
    let name: String
    let filename: String
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let hasSpecificTime: Bool
    let summary: String
    let locationContains: [String]
}
