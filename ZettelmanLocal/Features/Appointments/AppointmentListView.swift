import SwiftData
import SwiftUI
import UIKit

struct AppointmentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppointmentRecord.appointmentDate, order: .forward) private var appointments: [AppointmentRecord]

    @State private var isShowingSourceDialog = false
    @State private var isShowingCamera = false
    @State private var isShowingPhotoLibrary = false
    @State private var isProcessing = false
    @State private var pendingScan: PendingScan?
    @State private var alertMessage: AlertMessage?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.97, green: 0.95, blue: 0.90), Color(red: 0.93, green: 0.95, blue: 0.93)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if appointments.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(appointments) { appointment in
                                NavigationLink {
                                    AppointmentDetailView(appointment: appointment)
                                } label: {
                                    AppointmentRowView(appointment: appointment)
                                }
                                .listRowBackground(Color.white.opacity(0.86))
                            }
                            .onDelete(perform: deleteAppointments)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }

                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("Zetteltermine")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSourceDialog = true
                    } label: {
                        Label("Zettel scannen", systemImage: "plus.viewfinder")
                    }
                }
            }
        }
        .confirmationDialog("Zettel hinzufuegen", isPresented: $isShowingSourceDialog, titleVisibility: .visible) {
            Button("Foto aufnehmen") {
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    alertMessage = AlertMessage(message: "Auf diesem Geraet ist keine Kamera verfuegbar.")
                    return
                }
                isShowingCamera = true
            }

            Button("Aus Fotos waehlen") {
                isShowingPhotoLibrary = true
            }

            Button("Abbrechen", role: .cancel) {}
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { result in
                handlePickerResult(result, source: .camera)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingPhotoLibrary) {
            PhotoLibraryPicker { result in
                handlePickerResult(result, source: .library)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $pendingScan) { pending in
            ScanConfirmationView(
                image: pending.image,
                extracted: pending.extracted,
                onCancel: {
                    pendingScan = nil
                },
                onSave: { draft in
                    saveAppointment(from: pending, draft: draft)
                }
            )
        }
        .alert(item: $alertMessage) { item in
            Alert(title: Text("Hinweis"), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.teal)

            Text("Zettel rein, Termin raus")
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)

            Text("Fotografiere einen Arztzettel oder waehle ein Bild aus deinen Fotos. Vision OCR liest den Text lokal, du bestaetigst die Angaben, und alles bleibt auf dem Geraet.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)

            Button {
                isShowingSourceDialog = true
            } label: {
                Label("Ersten Zettel scannen", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.88), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                Text("OCR laeuft lokal auf dem Geraet")
                    .font(.headline)
                Text("Wir lesen Datum, Kurzbeschreibung und Ort aus dem Zettel.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(32)
        }
    }

    private func handlePickerResult(_ result: Result<UIImage, Error>, source: PickerSource) {
        switch source {
        case .camera:
            isShowingCamera = false
        case .library:
            isShowingPhotoLibrary = false
        }

        switch result {
        case .success(let image):
            process(image: image)
        case .failure(let error):
            guard let pickerError = error as? ImagePickerError, pickerError == .cancelled else {
                if let message = error.localizedDescription.nilIfEmpty {
                    alertMessage = AlertMessage(message: message)
                }
                return
            }
        }
    }

    private func process(image: UIImage) {
        isProcessing = true

        Task { @MainActor in
            do {
                let scanner = AppointmentScanner()
                let extracted = try await scanner.scan(image: image)
                pendingScan = PendingScan(image: image, extracted: extracted)
            } catch {
                alertMessage = AlertMessage(message: error.localizedDescription.nilIfEmpty ?? "Der Zettel konnte nicht verarbeitet werden.")
            }
            isProcessing = false
        }
    }

    private func saveAppointment(from pending: PendingScan, draft: AppointmentDraft) {
        do {
            let filename = try ScannedImageStore.shared.save(image: pending.image)
            let record = AppointmentRecord(
                appointmentDate: draft.appointmentDate,
                hasSpecificTime: draft.hasSpecificTime,
                summaryText: draft.summary,
                locationText: draft.location,
                imageFilename: filename,
                recognizedText: pending.extracted.recognizedText
            )
            modelContext.insert(record)
            try modelContext.save()
            pendingScan = nil
        } catch {
            alertMessage = AlertMessage(message: error.localizedDescription.nilIfEmpty ?? "Der Termin konnte nicht gespeichert werden.")
        }
    }

    private func deleteAppointments(at offsets: IndexSet) {
        for index in offsets {
            let appointment = appointments[index]
            ScannedImageStore.shared.delete(filename: appointment.imageFilename)
            modelContext.delete(appointment)
        }

        do {
            try modelContext.save()
        } catch {
            alertMessage = AlertMessage(message: error.localizedDescription.nilIfEmpty ?? "Der Termin konnte nicht geloescht werden.")
        }
    }
}

private struct AppointmentRowView: View {
    let appointment: AppointmentRecord

    var body: some View {
        HStack(spacing: 14) {
            AppointmentThumbnailView(filename: appointment.imageFilename)

            VStack(alignment: .leading, spacing: 6) {
                Text(appointment.summaryText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Label(AppointmentPresentation.formattedDate(appointment.appointmentDate, hasSpecificTime: appointment.hasSpecificTime), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(appointment.locationText, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}

private struct AppointmentThumbnailView: View {
    let filename: String

    var body: some View {
        Group {
            if let image = ScannedImageStore.shared.loadImage(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.18)
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 76, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct AlertMessage: Identifiable {
    let id = UUID()
    let message: String
}

private enum PickerSource {
    case camera
    case library
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
