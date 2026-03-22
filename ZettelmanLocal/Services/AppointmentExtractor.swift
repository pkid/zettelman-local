import Foundation

struct AppointmentExtractor {
    private let calendar = Calendar(identifier: .gregorian)
    private let dateLabelKeywords = ["datum", "wochentag"]
    private let timeLabelKeywords = ["uhrzeit", "uhr"]
    private let summaryLabelKeywords = ["bereich", "grund", "anlass", "betreff", "was"]
    private let practiceKeywords = [
        "praxis", "zahnarztpraxis", "dr", "arzt", "hausarzt", "internist", "frauenheilkunde",
        "gemeinschaftspraxis", "mvz", "klinik", "ambulanz"
    ]
    private let specialtyKeywords = [
        "frauenheilkunde", "geburtshilfe", "hausarzt", "internist", "zahnarzt", "orthopaedie",
        "radiologie", "labor", "physio", "sprechstunde"
    ]
    private let summaryKeywords = [
        "kontrolle", "nachsorge", "beratung", "untersuchung", "sprechstunde", "check", "checkup",
        "impfung", "blutabnahme", "labor", "gespraech", "erstgespraech", "mrt", "ct", "rontgen",
        "ultraschall", "physio", "physiotherapie", "behandlung", "diagnostik", "besprechung"
    ]
    private let specialtyFallbacks: [(keyword: String, summary: String)] = [
        ("zahnarztpraxis", "Zahnarzttermin"),
        ("frauenheilkunde", "Frauenarzttermin"),
        ("hausarzt und internist", "Hausarzttermin"),
        ("hausarzt", "Hausarzttermin"),
        ("physiotherapie", "Physiotherapietermin"),
        ("physio", "Physiotherapietermin")
    ]
    private let streetKeywords = ["strasse", "str.", "str ", "str", "marktstrasse", "platz", "weg", "allee", "gasse", "ring", "ufer"]
    private let monthLookup: [String: Int] = [
        "januar": 1,
        "februar": 2,
        "maerz": 3,
        "marz": 3,
        "april": 4,
        "mai": 5,
        "juni": 6,
        "juli": 7,
        "august": 8,
        "september": 9,
        "oktober": 10,
        "november": 11,
        "dezember": 12
    ]

    func extract(from recognizedText: RecognizedText, referenceDate: Date = .now) -> ExtractedAppointment {
        let lines = makeLines(from: recognizedText)
        let dateValue = extractDate(from: lines, referenceDate: referenceDate)
        let locationValue = extractLocation(from: lines)
        let summaryValue = extractSummary(from: lines, chosenLocation: locationValue.value)

        return ExtractedAppointment(
            appointmentDate: dateValue,
            summary: summaryValue,
            location: locationValue,
            recognizedText: lines.map({ line in line.text }).joined(separator: "\n")
        )
    }

    private func makeLines(from recognizedText: RecognizedText) -> [ParsedLine] {
        recognizedText.lines.enumerated().compactMap { offset, line in
            let normalized = cleanWhitespace(normalizeOCRArtifacts(line.text))
            guard normalized.isEmpty == false else {
                return nil
            }
            return ParsedLine(index: offset, text: normalized, folded: folded(normalized))
        }
    }

    private func extractDate(from lines: [ParsedLine], referenceDate: Date) -> ExtractedDateValue {
        if let labelledDate = labelledDateCandidate(in: lines, referenceDate: referenceDate) {
            return labelledDate
        }

        if let genericDate = genericDateCandidate(in: lines, referenceDate: referenceDate) {
            return genericDate
        }

        return ExtractedDateValue(
            value: nil,
            hasSpecificTime: false,
            confidence: .missing,
            reason: "Kein Datum erkannt"
        )
    }

    private func labelledDateCandidate(in lines: [ParsedLine], referenceDate: Date) -> ExtractedDateValue? {
        let dateLabelIndexes = indexes(in: lines, matchingAny: dateLabelKeywords)
        let timeLabelIndexes = indexes(in: lines, matchingAny: timeLabelKeywords)

        for dateIndex in dateLabelIndexes {
            let nearbyValues = nearbyValueTexts(around: dateIndex, lines: lines)
            for valueText in nearbyValues {
                if let parsed = parseDate(in: valueText, referenceDate: referenceDate) {
                    let upgraded = addLabelledTimeIfNeeded(to: parsed, using: timeLabelIndexes, lines: lines, referenceDate: referenceDate)
                    let reason = lines[dateIndex].folded.contains("wochentag")
                        ? "Aus handschriftlicher Zeile neben Datumslabel"
                        : "Aus Datum/Uhrzeit-Label"
                    return ExtractedDateValue(
                        value: upgraded.date,
                        hasSpecificTime: upgraded.hadTime,
                        confidence: .high,
                        reason: reason
                    )
                }
            }
        }

        if let rowIndex = lines.firstIndex(where: { line in
            line.folded.contains("wochentag") && line.folded.contains("datum") && line.folded.contains("uhr")
        }) {
            let joinedText = nearbyValueTexts(around: rowIndex, lines: lines).joined(separator: " ")
            if let parsed = parseDate(in: joinedText, referenceDate: referenceDate) {
                return ExtractedDateValue(
                    value: parsed.date,
                    hasSpecificTime: parsed.hadTime,
                    confidence: .high,
                    reason: "Aus handschriftlicher Zeile neben Datumslabel"
                )
            }
        }

        if let explicitDateText = nearestLabelValue(for: dateLabelKeywords, in: lines),
           let parsedDate = parseDate(in: explicitDateText, referenceDate: referenceDate) {
            let upgraded = addLabelledTimeIfNeeded(to: parsedDate, using: timeLabelIndexes, lines: lines, referenceDate: referenceDate)
            return ExtractedDateValue(
                value: upgraded.date,
                hasSpecificTime: upgraded.hadTime,
                confidence: .high,
                reason: "Aus Datum/Uhrzeit-Label"
            )
        }

        return nil
    }

    private func addLabelledTimeIfNeeded(
        to parsedDate: ParsedDate,
        using timeLabelIndexes: [Int],
        lines: [ParsedLine],
        referenceDate: Date
    ) -> ParsedDate {
        guard parsedDate.hadTime == false else {
            return parsedDate
        }

        for timeIndex in timeLabelIndexes {
            let candidateTexts = nearbyValueTexts(around: timeIndex, lines: lines)
            for text in candidateTexts {
                guard let time = parseTime(in: text) else {
                    continue
                }
                let combinedDate = combining(date: parsedDate.date, time: time)
                return ParsedDate(date: combinedDate, hadTime: true)
            }
        }

        return parsedDate
    }

    private func genericDateCandidate(in lines: [ParsedLine], referenceDate: Date) -> ExtractedDateValue? {
        var candidates: [DateExtractionCandidate] = []

        for line in lines {
            if let parsedDate = parseDate(in: line.text, referenceDate: referenceDate) {
                let score = scoreDateCandidate(text: line.folded, parsedDate: parsedDate, lineIndex: line.index, lines: lines, referenceDate: referenceDate)
                candidates.append(
                    DateExtractionCandidate(
                        date: parsedDate.date,
                        hasSpecificTime: parsedDate.hadTime,
                        score: score,
                        reason: parsedDate.hadTime ? "Aus OCR-Muster mit Uhrzeit" : "Aus OCR-Muster ohne Label"
                    )
                )
            }
        }

        guard let best = candidates.max(by: { lhs, rhs in lhs.score < rhs.score }) else {
            return nil
        }

        return ExtractedDateValue(
            value: best.date,
            hasSpecificTime: best.hasSpecificTime,
            confidence: best.score >= 8 ? .high : .guessed,
            reason: best.reason
        )
    }

    private func extractSummary(from lines: [ParsedLine], chosenLocation: String) -> ExtractedTextValue {
        if let labelledSummary = labelledSummaryCandidate(in: lines) {
            return labelledSummary
        }

        if let keywordSummary = keywordSummaryCandidate(in: lines, chosenLocation: chosenLocation) {
            return keywordSummary
        }

        let fullText = lines.map({ line in line.folded }).joined(separator: " ")
        for fallback in specialtyFallbacks {
            if fullText.contains(fallback.keyword) {
                return ExtractedTextValue(
                    value: fallback.summary,
                    confidence: .guessed,
                    reason: "Aus Praxistyp abgeleitet"
                )
            }
        }

        return ExtractedTextValue(
            value: "Arzttermin",
            confidence: .guessed,
            reason: "Allgemeiner Fallback"
        )
    }

    private func labelledSummaryCandidate(in lines: [ParsedLine]) -> ExtractedTextValue? {
        for line in lines {
            for label in summaryLabelKeywords where line.folded.contains(label) {
                let inlineValue = stripLabel(label, from: line.text)
                if isUsefulSummaryValue(inlineValue) {
                    return ExtractedTextValue(
                        value: clampSummary(inlineValue),
                        confidence: .high,
                        reason: "Aus \(label.capitalized)"
                    )
                }

                if let nextValue = bestNearbySummaryValue(after: line.index, in: lines) {
                    return ExtractedTextValue(
                        value: clampSummary(nextValue),
                        confidence: .high,
                        reason: "Aus \(label.capitalized)"
                    )
                }
            }
        }

        return nil
    }

    private func keywordSummaryCandidate(in lines: [ParsedLine], chosenLocation: String) -> ExtractedTextValue? {
        let foldedLocation = folded(chosenLocation)
        var candidates: [(text: String, score: Int)] = []

        for line in lines {
            guard line.folded != foldedLocation else {
                continue
            }
            guard looksLikeDateString(line.folded) == false else {
                continue
            }
            guard looksLikeContactLine(line.folded) == false else {
                continue
            }
            guard looksLikePostalAddress(line.folded) == false else {
                continue
            }
            guard isGenericAppointmentHeader(line.folded) == false else {
                continue
            }

            var score = 0
            let hasSummaryKeyword = summaryKeywords.contains(where: { keyword in line.folded.contains(keyword) })
            let hasTerminKeyword = line.folded.contains("termin")

            if hasSummaryKeyword {
                score += 6
            }
            if hasTerminKeyword {
                score += 2
            }
            guard hasSummaryKeyword || hasTerminKeyword else {
                continue
            }

            let wordCount = words(in: line.text).count
            if hasSummaryKeyword == false && hasTerminKeyword && wordCount > 3 {
                continue
            }
            if wordCount <= 5 {
                score += 2
            } else if wordCount <= 8 {
                score += 1
            } else {
                score -= 1
            }
            if practiceKeywords.contains(where: { keyword in line.folded.contains(keyword) }) {
                score -= 2
            }

            if score > 0 {
                let cleaned = sanitizeSummary(line.text)
                if isUsefulSummaryValue(cleaned) {
                    let cleanedFolded = folded(cleaned)
                    // Avoid using clinic header fragments as "what" when they are already in location.
                    if words(in: cleaned).count >= 3 && foldedLocation.contains(cleanedFolded) {
                        continue
                    }
                    candidates.append((text: clampSummary(cleaned), score: score))
                }
            }
        }

        guard let best = candidates.max(by: { lhs, rhs in lhs.score < rhs.score }) else {
            return nil
        }

        return ExtractedTextValue(
            value: best.text,
            confidence: best.score >= 7 ? .high : .guessed,
            reason: "Aus OCR-Stichworten"
        )
    }

    private func extractLocation(from lines: [ParsedLine]) -> ExtractedTextValue {
        let practiceCandidates = locationPracticeCandidates(in: lines)
        let addressCandidates = locationAddressCandidates(in: lines)

        let practice = practiceCandidates.max(by: { lhs, rhs in lhs.score < rhs.score })
        let address = addressCandidates.max(by: { lhs, rhs in lhs.score < rhs.score })

        var pieces: [String] = []

        if let practice {
            pieces.append(practice.text)
            if let companion = companionLine(for: practice.lineIndex, in: lines), pieces.contains(companion) == false {
                pieces.append(companion)
            }
        }

        if let address {
            if pieces.contains(address.text) == false {
                pieces.append(address.text)
            }
            if let nextAddress = nextAddressLine(after: address.lineIndex, in: lines), pieces.contains(nextAddress) == false {
                pieces.append(nextAddress)
            }
        }

        let cleanedPieces = uniquePreservingOrder(pieces.map(sanitizeLocationPiece).filter { $0.isEmpty == false })
        let location = cleanedPieces.joined(separator: ", ")

        if location.isEmpty == false {
            let reason: String
            let confidence: ExtractionConfidence
            if practice != nil && address != nil {
                reason = "Aus Praxiskopf und Adressblock"
                confidence = .high
            } else if practice != nil {
                reason = "Aus Praxiskopf"
                confidence = .high
            } else {
                reason = "Aus Adressblock"
                confidence = .guessed
            }

            return ExtractedTextValue(value: location, confidence: confidence, reason: reason)
        }

        if let fallback = fallbackLocation(in: lines) {
            return ExtractedTextValue(value: fallback, confidence: .guessed, reason: "Aus OCR-Text geschaetzt")
        }

        return ExtractedTextValue(value: "Ort pruefen", confidence: .missing, reason: "Kein Ort erkannt")
    }

    private func locationPracticeCandidates(in lines: [ParsedLine]) -> [LocationCandidate] {
        var candidates: [LocationCandidate] = []

        for line in lines {
            let sanitized = sanitizeLocationPiece(line.text)
            guard sanitized.isEmpty == false else {
                continue
            }
            guard looksLikeDateString(line.folded) == false else {
                continue
            }
            guard looksLikeContactLine(line.folded) == false else {
                continue
            }
            guard looksMostlyNumeric(line.text) == false else {
                continue
            }

            var score = 0
            if practiceKeywords.contains(where: { keyword in line.folded.contains(keyword) }) {
                score += 8
            }
            if line.folded.contains("dr") {
                score += 5
            }
            if specialtyKeywords.contains(where: { keyword in line.folded.contains(keyword) }) {
                score += 3
            }
            if line.index <= 2 {
                score += 3
            }
            if looksLikePostalAddress(line.folded) {
                score -= 3
            }
            if sanitized.count > 70 {
                score -= 2
            }

            if score > 0 {
                candidates.append(LocationCandidate(text: sanitized, lineIndex: line.index, score: score))
            }
        }

        return candidates
    }

    private func locationAddressCandidates(in lines: [ParsedLine]) -> [LocationCandidate] {
        var candidates: [LocationCandidate] = []

        for line in lines {
            let sanitized = sanitizeLocationPiece(line.text)
            guard sanitized.isEmpty == false else {
                continue
            }

            var score = 0
            if looksLikePostalAddress(line.folded) {
                score += 6
            }
            if streetKeywords.contains(where: { keyword in line.folded.contains(keyword) }) {
                score += 4
            }
            if score > 0 {
                candidates.append(LocationCandidate(text: sanitized, lineIndex: line.index, score: score))
            }
        }

        return candidates
    }

    private func fallbackLocation(in lines: [ParsedLine]) -> String? {
        for line in lines {
            let sanitized = sanitizeLocationPiece(line.text)
            guard sanitized.isEmpty == false else {
                continue
            }
            guard looksLikeDateString(line.folded) == false else {
                continue
            }
            guard looksLikeContactLine(line.folded) == false else {
                continue
            }
            if words(in: sanitized).count >= 2 {
                return sanitized
            }
        }

        return nil
    }

    private func companionLine(for lineIndex: Int, in lines: [ParsedLine]) -> String? {
        let candidateIndexes = [lineIndex + 1, lineIndex - 1]

        for index in candidateIndexes where lines.indices.contains(index) {
            let line = lines[index]
            let sanitized = sanitizeLocationPiece(line.text)
            guard sanitized.isEmpty == false else {
                continue
            }
            guard specialtyKeywords.contains(where: { keyword in line.folded.contains(keyword) }) else {
                continue
            }
            guard looksLikeContactLine(line.folded) == false else {
                continue
            }
            return sanitized
        }

        return nil
    }

    private func nearbyValueTexts(around lineIndex: Int, lines: [ParsedLine]) -> [String] {
        var values: [String] = []
        let indexes = [lineIndex, lineIndex + 1, lineIndex + 2]

        for index in indexes where lines.indices.contains(index) {
            let line = lines[index]
            let cleaned = stripLabels(from: line.text)
            if cleaned.isEmpty == false {
                values.append(cleaned)
            }
        }

        if values.count >= 2 {
            values.append(values[0] + " " + values[1])
        }
        if values.count >= 3 {
            values.append(values[1] + " " + values[2])
            values.append(values[0] + " " + values[1] + " " + values[2])
        }

        return uniquePreservingOrder(values)
    }

    private func nearestLabelValue(for labels: [String], in lines: [ParsedLine]) -> String? {
        for line in lines where labels.contains(where: { label in line.folded.contains(label) }) {
            let stripped = stripLabels(from: line.text)
            if stripped.isEmpty == false {
                return stripped
            }
            if let nextValue = firstUsefulValue(after: line.index, in: lines, skippingLabels: labels) {
                return nextValue
            }
        }

        return nil
    }

    private func firstUsefulValue(after lineIndex: Int, in lines: [ParsedLine], skippingLabels labels: [String]) -> String? {
        let range = (lineIndex + 1)...min(lineIndex + 2, lines.count - 1)
        for index in range {
            let line = lines[index]
            if labels.contains(where: { label in line.folded.contains(label) }) {
                continue
            }
            let stripped = stripLabels(from: line.text)
            if stripped.isEmpty == false {
                return stripped
            }
        }
        return nil
    }

    private func bestNearbySummaryValue(after lineIndex: Int, in lines: [ParsedLine]) -> String? {
        let upperBound = min(lineIndex + 4, lines.count - 1)
        guard lineIndex + 1 <= upperBound else {
            return nil
        }

        var best: (text: String, score: Int)?
        for index in (lineIndex + 1)...upperBound {
            let line = lines[index]
            if summaryLabelKeywords.contains(where: { label in line.folded.contains(label) }) {
                continue
            }

            let cleaned = sanitizeSummary(line.text)
            guard isUsefulSummaryValue(cleaned) else {
                continue
            }

            var score = 0
            if summaryKeywords.contains(where: { keyword in line.folded.contains(keyword) }) {
                score += 6
            }
            if specialtyKeywords.contains(where: { keyword in line.folded.contains(keyword) }) {
                score += 4
            }
            if practiceKeywords.contains(where: { keyword in line.folded.contains(keyword) }) {
                score -= 3
            }

            let wordCount = words(in: cleaned).count
            if wordCount <= 3 {
                score += 3
            } else if wordCount <= 5 {
                score += 2
            }

            score += max(0, 4 - (index - lineIndex))

            if let best, best.score >= score {
                continue
            }
            best = (cleaned, score)
        }

        return best?.text
    }

    private func parseDate(in text: String, referenceDate: Date) -> ParsedDate? {
        let normalizedText = normalizeOCRArtifacts(folded(text))

        if let parsed = parseNumericDate(in: normalizedText, referenceDate: referenceDate) {
            return parsed
        }
        if let parsed = parseNamedMonthDate(in: normalizedText, referenceDate: referenceDate) {
            return parsed
        }

        return nil
    }

    private func parseNumericDate(in text: String, referenceDate: Date) -> ParsedDate? {
        let numericText = normalizeNumericLikeCharacters(in: text)
        let pattern = "(?:(?:mo|di|mi|do|fr|sa|so|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)\\.?\\s*,?\\s*)?(\\d{1,2})[./-](\\d{1,2})(?:[./-]?(\\d{2,4}))?(?:\\s*(?:um)?\\s*(\\d{1,2})[:.](\\d{2})\\s*(?:uhr|umr|uhrz)?\\b)?"
        return firstParsedDate(in: numericText, pattern: pattern) { groups in
            guard let day = Int(groups[0]), let month = Int(groups[1]) else {
                return nil
            }

            let year = Int(groups[2])
            let hour = Int(groups[3])
            let minute = Int(groups[4])
            guard let date = buildDate(day: day, month: month, year: year, hour: hour, minute: minute, referenceDate: referenceDate) else {
                return nil
            }

            return ParsedDate(date: date, hadTime: hour != nil && minute != nil)
        }
    }

    private func parseNamedMonthDate(in text: String, referenceDate: Date) -> ParsedDate? {
        let pattern = "(?:(?:montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)\\.?\\s*,?\\s*)?(\\d{1,2})\\.?\\s*(januar|februar|maerz|marz|april|mai|juni|juli|august|september|oktober|november|dezember)\\s*(\\d{2,4})?(?:\\s*(?:um)?\\s*(\\d{1,2})[:.](\\d{2})\\s*(?:uhr|umr)?\\b)?"
        return firstParsedDate(in: text, pattern: pattern) { groups in
            guard let day = Int(groups[0]), let month = monthLookup[groups[1]] else {
                return nil
            }

            let year = Int(groups[2])
            let hour = Int(groups[3])
            let minute = Int(groups[4])
            guard let date = buildDate(day: day, month: month, year: year, hour: hour, minute: minute, referenceDate: referenceDate) else {
                return nil
            }

            return ParsedDate(date: date, hadTime: hour != nil && minute != nil)
        }
    }

    private func parseTime(in text: String) -> (hour: Int, minute: Int)? {
        let normalizedText = normalizeNumericLikeCharacters(in: normalizeOCRArtifacts(folded(text)))
        let pattern = #"(?<![\d.])(\d{1,2})[:.](\d{2})(?![\d./-])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let matches = regex.matches(in: normalizedText, range: NSRange(normalizedText.startIndex..., in: normalizedText))
        guard let match = matches.first else {
            return nil
        }
        guard let hourRange = Range(match.range(at: 1), in: normalizedText),
              let minuteRange = Range(match.range(at: 2), in: normalizedText),
              let hour = Int(normalizedText[hourRange]),
              let minute = Int(normalizedText[minuteRange]) else {
            return nil
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func firstParsedDate(in text: String, pattern: String, parser: ([String]) -> ParsedDate?) -> ParsedDate? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            var groups: [String] = []
            for index in 1..<match.numberOfRanges {
                let range = match.range(at: index)
                if range.location == NSNotFound {
                    groups.append("")
                    continue
                }
                if let swiftRange = Range(range, in: text) {
                    groups.append(String(text[swiftRange]))
                } else {
                    groups.append("")
                }
            }

            if let parsed = parser(groups) {
                return parsed
            }
        }

        return nil
    }

    private func buildDate(
        day: Int,
        month: Int,
        year: Int?,
        hour: Int?,
        minute: Int?,
        referenceDate: Date
    ) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else {
            return nil
        }

        let normalizedYear: Int
        if let year {
            normalizedYear = year < 100 ? 2000 + year : year
        } else {
            normalizedYear = calendar.component(.year, from: referenceDate)
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = .autoupdatingCurrent
        components.day = day
        components.month = month
        components.year = normalizedYear
        components.hour = hour ?? 9
        components.minute = minute ?? 0

        guard var date = calendar.date(from: components) else {
            return nil
        }

        if year == nil, date < referenceDate.addingTimeInterval(-30 * 24 * 60 * 60) {
            date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }

        return date
    }

    private func combining(date: Date, time: (hour: Int, minute: Int)) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        components.timeZone = .autoupdatingCurrent
        return calendar.date(from: components) ?? date
    }

    private func scoreDateCandidate(
        text: String,
        parsedDate: ParsedDate,
        lineIndex: Int,
        lines: [ParsedLine],
        referenceDate: Date
    ) -> Int {
        var score = 0

        if dateLabelKeywords.contains(where: { keyword in text.contains(keyword) }) || timeLabelKeywords.contains(where: { keyword in text.contains(keyword) }) {
            score += 4
        }
        if parsedDate.hadTime {
            score += 3
        }
        if parsedDate.date >= referenceDate.addingTimeInterval(-7 * 24 * 60 * 60) {
            score += 2
        }
        if let previous = lines.first(where: { $0.index == lineIndex - 1 }),
           (dateLabelKeywords.contains(where: { keyword in previous.folded.contains(keyword) }) || timeLabelKeywords.contains(where: { keyword in previous.folded.contains(keyword) })) {
            score += 3
        }
        if text.contains("geb") || text.contains("ausgestellt") || text.contains("rechnung") {
            score -= 8
        }

        return score
    }

    private func indexes(in lines: [ParsedLine], matchingAny keywords: [String]) -> [Int] {
        lines.compactMap { line in
            keywords.contains(where: { keyword in line.folded.contains(keyword) }) ? line.index : nil
        }
    }

    private func stripLabels(from text: String) -> String {
        let labels = dateLabelKeywords + timeLabelKeywords + summaryLabelKeywords
        var result = text
        for label in labels {
            result = stripLabel(label, from: result)
        }
        return cleanWhitespace(result)
    }

    private func stripLabel(_ label: String, from text: String) -> String {
        let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: label) + "\\b\\s*[:\\-]?"
        return cleanWhitespace(text.replacingOccurrences(of: pattern, with: "", options: .regularExpression))
    }

    private func isUsefulSummaryValue(_ text: String) -> Bool {
        let cleaned = sanitizeSummary(text)
        guard cleaned.isEmpty == false else {
            return false
        }
        let foldedCleaned = folded(cleaned)
        guard looksLikeDateString(foldedCleaned) == false else {
            return false
        }
        if let parsedTime = parseTime(in: foldedCleaned), words(in: cleaned).count == 1 {
            let normalizedTime = String(format: "%02d:%02d", parsedTime.hour, parsedTime.minute)
            if cleaned.contains(normalizedTime) || cleaned.contains(normalizedTime.replacingOccurrences(of: ":", with: ".")) || cleaned.range(of: #"^\d{1,2}[:.]\d{2}$"#, options: .regularExpression) != nil {
                return false
            }
        }
        guard dateLabelKeywords.contains(foldedCleaned) == false else {
            return false
        }
        guard timeLabelKeywords.contains(foldedCleaned) == false else {
            return false
        }
        guard summaryLabelKeywords.contains(foldedCleaned) == false else {
            return false
        }
        guard isGenericAppointmentHeader(foldedCleaned) == false else {
            return false
        }
        return true
    }

    private func sanitizeSummary(_ text: String) -> String {
        let stripped = stripLabels(from: text)
        return cleanWhitespace(stripped)
    }

    private func clampSummary(_ text: String) -> String {
        let limited = words(in: text).prefix(5)
        if limited.isEmpty {
            return "Arzttermin"
        }
        return limited.joined(separator: " ")
    }

    private func sanitizeLocationPiece(_ text: String) -> String {
        var sanitized = cleanWhitespace(text)
        let noiseMarkers = ["tel", "telefon", "fax", "fon", "www", "http", "info@", "mail"]
        let foldedSanitized = folded(sanitized)

        for marker in noiseMarkers {
            if let range = foldedSanitized.range(of: marker) {
                let distance = foldedSanitized.distance(from: foldedSanitized.startIndex, to: range.lowerBound)
                let endIndex = sanitized.index(sanitized.startIndex, offsetBy: distance)
                sanitized = String(sanitized[..<endIndex])
                break
            }
        }

        sanitized = sanitized.replacingOccurrences(of: "|", with: ", ")
        sanitized = cleanWhitespace(sanitized)
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: ",.- "))
        return sanitized
    }

    private func nextAddressLine(after lineIndex: Int, in lines: [ParsedLine]) -> String? {
        let nextIndex = lineIndex + 1
        guard lines.indices.contains(nextIndex) else {
            return nil
        }

        let nextLine = lines[nextIndex]
        guard looksLikeContactLine(nextLine.folded) == false else {
            return nil
        }
        guard looksLikePostalAddress(nextLine.folded) || streetKeywords.contains(where: { keyword in nextLine.folded.contains(keyword) }) else {
            return nil
        }
        return sanitizeLocationPiece(nextLine.text)
    }

    private func looksLikeDateString(_ text: String) -> Bool {
        let numericPattern = #"\b\d{1,2}[./-]\d{1,2}(?:[./-]?\d{2,4})?\b"#
        if text.range(of: numericPattern, options: .regularExpression) != nil {
            return true
        }
        let monthPattern = #"\b(januar|februar|maerz|marz|april|mai|juni|juli|august|september|oktober|november|dezember)\b"#
        return text.range(of: monthPattern, options: .regularExpression) != nil
    }

    private func looksLikePostalAddress(_ text: String) -> Bool {
        if streetKeywords.contains(where: { keyword in text.contains(keyword) }) {
            return true
        }
        let postalCodePattern = #"\b\d{5}\s+[a-z]"#
        return text.range(of: postalCodePattern, options: .regularExpression) != nil
    }

    private func looksLikeContactLine(_ text: String) -> Bool {
        ["tel", "telefon", "fax", "fon", "www", "http", "info@", "mail"].contains(where: { marker in
            text.contains(marker)
        })
    }

    private func looksMostlyNumeric(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { scalar in CharacterSet.alphanumerics.contains(scalar) }
        guard scalars.isEmpty == false else {
            return false
        }
        let digitCount = scalars.filter { scalar in CharacterSet.decimalDigits.contains(scalar) }.count
        return Double(digitCount) / Double(scalars.count) > 0.6
    }

    private func normalizeOCRArtifacts(_ text: String) -> String {
        var normalized = text
        let replacements: [(String, String)] = [
            ("umr", "uhr"),
            ("uhrz", "uhr"),
            ("  ", " ")
        ]
        for replacement in replacements {
            normalized = normalized.replacingOccurrences(of: replacement.0, with: replacement.1)
        }
        normalized = normalized.replacingOccurrences(
            of: #"(\d{1,2})\.(\d)(\d{2})(\d{1,2}[:.]\d{2})"#,
            with: "$1.$2.$3 $4",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(\d{1,2}\.\d{1,2}\.?\d{2})(\d{1,2}[:.]\d{2})"#,
            with: "$1 $2",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(\d{1,2}[./-]\d{1,2}[./-]?\d{2,4})([A-Za-z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        return normalized
    }

    private func normalizeNumericLikeCharacters(in text: String) -> String {
        let mappedScalars = text.unicodeScalars.map { scalar -> UnicodeScalar in
            switch scalar {
            case "o", "O":
                return "0"
            case "l", "I", "i", "|", "!":
                return "1"
            case "s", "S":
                return "5"
            case "b", "B":
                return "8"
            default:
                return scalar
            }
        }
        return String(String.UnicodeScalarView(mappedScalars))
    }

    private func words(in text: String) -> [String] {
        cleanWhitespace(text).split(whereSeparator: { character in character.isWhitespace }).map(String.init)
    }

    private func cleanWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
    }

    private func isGenericAppointmentHeader(_ text: String) -> Bool {
        let genericHeaders = [
            "termine",
            "ihre naechsten termine",
            "ihr naechster termin",
            "ihr naechster termin bei uns",
            "ihr nachster termin",
            "ihr nachster termin bei uns"
        ]

        if genericHeaders.contains(text) {
            return true
        }

        return text.contains("termin bei uns") || text.contains("naechsten termine") || text.contains("nachsten termine")
    }

    private func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values {
            let key = folded(value)
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            result.append(value)
        }

        return result
    }
}

private struct ParsedLine {
    let index: Int
    let text: String
    let folded: String
}

private struct ParsedDate {
    let date: Date
    let hadTime: Bool
}

private struct DateExtractionCandidate {
    let date: Date
    let hasSpecificTime: Bool
    let score: Int
    let reason: String
}

private struct LocationCandidate {
    let text: String
    let lineIndex: Int
    let score: Int
}
