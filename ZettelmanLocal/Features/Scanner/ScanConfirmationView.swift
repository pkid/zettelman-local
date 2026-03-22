import SwiftUI
import UIKit

struct ScanConfirmationView: View {
    let image: UIImage
    let extracted: ExtractedAppointment
    let onCancel: () -> Void
    let onSave: (AppointmentDraft) -> Void

    @State private var appointmentDate: Date
    @State private var hasSpecificTime: Bool
    @State private var summary: String
    @State private var location: String
    @State private var isShowingZoom = false
    @State private var isRecognizedTextExpanded = false

    init(
        image: UIImage,
        extracted: ExtractedAppointment,
        onCancel: @escaping () -> Void,
        onSave: @escaping (AppointmentDraft) -> Void
    ) {
        self.image = image
        self.extracted = extracted
        self.onCancel = onCancel
        self.onSave = onSave

        let suggestedDate = extracted.appointmentDate.value
            ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)
            ?? .now
        _appointmentDate = State(initialValue: suggestedDate)
        _hasSpecificTime = State(initialValue: extracted.appointmentDate.value != nil && extracted.appointmentDate.hasSpecificTime)
        _summary = State(initialValue: extracted.summary.value)
        _location = State(initialValue: extracted.location.value)
    }

    private var summaryWordCount: Int {
        AppointmentPresentation.wordCount(in: summary)
    }

    private var canSave: Bool {
        summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && summaryWordCount <= 5
            && location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var locationLooksNoisy: Bool {
        AppointmentPresentation.isLocationNoisy(location)
    }

    private var reviewHints: [String] {
        var hints: [String] = []
        if extracted.appointmentDate.confidence != .high || hasSpecificTime == false {
            hints.append("Datum oder Uhrzeit bitte pruefen")
        }
        if extracted.summary.confidence != .high {
            hints.append("Kurzbeschreibung wurde geschaetzt")
        }
        if extracted.location.confidence != .high || locationLooksNoisy {
            hints.append("Ort wirkt unvollstaendig oder verrauscht")
        }
        return hints
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                quickActionsSection
                confirmationSection
                recognizedTextSection
            }
            .navigationTitle("Termin pruefen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(
                            AppointmentDraft(
                                appointmentDate: appointmentDate,
                                hasSpecificTime: hasSpecificTime,
                                summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                                location: AppointmentPresentation.trimLocationNoise(location)
                            )
                        )
                    }
                    .disabled(canSave == false)
                }
            }
            .fullScreenCover(isPresented: $isShowingZoom) {
                ZoomableImageViewer(image: image)
            }
        }
        .presentationDetents([.large])
    }

    private var previewSection: some View {
        Section {
            Button {
                isShowingZoom = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Label("Zoomen", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                }
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0))
        } header: {
            Text("Zettel")
        }
    }

    private var quickActionsSection: some View {
        Section("Schnellkorrekturen") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    QuickActionButton(title: "Arzttermin", systemImage: "stethoscope") {
                        summary = "Arzttermin"
                    }
                    QuickActionButton(title: "Zeit loeschen", systemImage: "clock.badge.xmark") {
                        hasSpecificTime = false
                    }
                    QuickActionButton(title: "Adresse kuerzen", systemImage: "scissors") {
                        location = AppointmentPresentation.trimLocationNoise(location)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var confirmationSection: some View {
        Section {
            if reviewHints.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Diese Felder brauchen vermutlich noch einen Blick.", systemImage: "exclamationmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(reviewHints, id: \.self) { hint in
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            ExtractionFieldHeader(
                title: "Wann",
                confidence: extracted.appointmentDate.confidence,
                reason: extracted.appointmentDate.reason,
                highlight: extracted.appointmentDate.confidence != .high || hasSpecificTime == false
            )
            DatePicker("Datum", selection: $appointmentDate, displayedComponents: [.date])
            Toggle("Uhrzeit vorhanden", isOn: $hasSpecificTime)
            if hasSpecificTime {
                DatePicker("Uhrzeit", selection: $appointmentDate, displayedComponents: [.hourAndMinute])
            }

            ExtractionFieldHeader(
                title: "Was",
                confidence: extracted.summary.confidence,
                reason: extracted.summary.reason,
                highlight: extracted.summary.confidence != .high
            )
            TextField("Kurzbeschreibung", text: $summary)
                .textInputAutocapitalization(.words)
            HStack {
                Text("Maximal 5 Woerter")
                Spacer()
                Text("\(summaryWordCount)/5")
                    .foregroundStyle(summaryWordCount <= 5 ? Color.secondary : Color.red)
            }
            .font(.footnote)

            ExtractionFieldHeader(
                title: "Wo",
                confidence: extracted.location.confidence,
                reason: extracted.location.reason,
                highlight: extracted.location.confidence != .high || locationLooksNoisy
            )
            TextField("Ort", text: $location, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.words)
            if locationLooksNoisy {
                Label("Ort enthaelt vermutlich noch Kontakt- oder Website-Reste.", systemImage: "exclamationmark.bubble")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Termin bestaetigen")
        } footer: {
            Text("Alles bleibt lokal auf dem Geraet gespeichert, inklusive des gescannten Zettels.")
        }
    }

    private var recognizedTextSection: some View {
        Section {
            DisclosureGroup("Erkannter Text", isExpanded: $isRecognizedTextExpanded) {
                Text(extracted.recognizedText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }
}

private struct ExtractionFieldHeader: View {
    let title: String
    let confidence: ExtractionConfidence
    let reason: String
    let highlight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                ConfidenceBadge(confidence: confidence, highlight: highlight)
            }
            Text(reason)
                .font(.footnote)
                .foregroundStyle(highlight ? .orange : .secondary)
        }
        .padding(.top, 4)
    }
}

private struct ConfidenceBadge: View {
    let confidence: ExtractionConfidence
    let highlight: Bool

    private var tint: Color {
        switch confidence {
        case .high:
            return highlight ? .orange : .green
        case .guessed:
            return .orange
        case .missing:
            return .red
        }
    }

    var body: some View {
        Text(confidence.reviewLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ZoomableImageViewer: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var currentScale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(currentScale)
                    .offset(currentOffset)
                    .gesture(magnifyGesture.simultaneously(with: dragGesture))
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                currentScale = max(1, min(lastScale * value.magnification, 6))
            }
            .onEnded { _ in
                lastScale = currentScale
                if currentScale == 1 {
                    currentOffset = .zero
                    lastOffset = .zero
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard currentScale > 1 else {
                    return
                }
                currentOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = currentOffset
            }
    }
}
