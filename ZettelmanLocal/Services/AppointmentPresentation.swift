import Foundation

struct AppointmentPresentation {
    static func formattedDate(_ date: Date, hasSpecificTime: Bool, includeWeekday: Bool = false) -> String {
        var format = Date.FormatStyle(date: .abbreviated, time: hasSpecificTime ? .shortened : .omitted)
        if includeWeekday {
            format = format.weekday(.wide)
        }
        return date.formatted(format)
    }

    static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: { character in character.isWhitespace }).count
    }

    static func trimLocationNoise(_ text: String) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = sanitized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        let markers = ["tel", "telefon", "fax", "fon", "www", "http", "info@", "mail"]

        for marker in markers {
            if let range = lowered.range(of: marker) {
                let distance = lowered.distance(from: lowered.startIndex, to: range.lowerBound)
                let endIndex = sanitized.index(sanitized.startIndex, offsetBy: distance)
                sanitized = String(sanitized[..<endIndex])
                break
            }
        }

        sanitized = sanitized.replacingOccurrences(of: "|", with: ", ")
        sanitized = sanitized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: ",.- "))
    }

    static func isLocationNoisy(_ text: String) -> Bool {
        let lowered = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        let markers = ["tel", "telefon", "fax", "fon", "www", "http", "info@", "mail"]
        if markers.contains(where: lowered.contains) {
            return true
        }
        return text.count > 75
    }
}
