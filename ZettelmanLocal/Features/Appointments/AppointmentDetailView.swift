import SwiftUI
import UIKit

struct AppointmentDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let appointment: AppointmentRecord

    @State private var isShowingFullScreenImage = false

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.09, green: 0.10, blue: 0.12),
                Color(red: 0.13, green: 0.15, blue: 0.19)
            ]
        }
        return [
            Color(red: 0.98, green: 0.96, blue: 0.92),
            Color(red: 0.93, green: 0.95, blue: 0.93)
        ]
    }

    private var surfaceBackground: Color {
        if colorScheme == .dark {
            return Color(red: 0.15, green: 0.17, blue: 0.21).opacity(0.78)
        }
        return Color.white.opacity(0.82)
    }

    private var surfaceBorder: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.08)
        }
        return Color.black.opacity(0.06)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button {
                    isShowingFullScreenImage = true
                } label: {
                    AppointmentHeroImage(
                        filename: appointment.imageFilename,
                        backgroundColor: surfaceBackground,
                        borderColor: surfaceBorder
                    )
                }
                .buttonStyle(.plain)

                VStack(spacing: 14) {
                    DetailCard(
                        title: "Wann",
                        systemImage: "calendar.badge.clock",
                        value: AppointmentPresentation.formattedDate(
                            appointment.appointmentDate,
                            hasSpecificTime: appointment.hasSpecificTime,
                            includeWeekday: true
                        ),
                        backgroundColor: surfaceBackground,
                        borderColor: surfaceBorder
                    )
                    DetailCard(
                        title: "Was",
                        systemImage: "text.bubble",
                        value: appointment.summaryText,
                        backgroundColor: surfaceBackground,
                        borderColor: surfaceBorder
                    )
                    DetailCard(
                        title: "Wo",
                        systemImage: "mappin.circle",
                        value: appointment.locationText,
                        backgroundColor: surfaceBackground,
                        borderColor: surfaceBorder
                    )
                    if let fileURL = ScannedImageStore.shared.localURL(filename: appointment.imageFilename) {
                        DetailCard(
                            title: "Lokaler Zettel",
                            systemImage: "externaldrive.badge.checkmark",
                            value: fileURL.lastPathComponent,
                            backgroundColor: surfaceBackground,
                            borderColor: surfaceBorder
                        )
                    }
                }

                if appointment.recognizedText.isEmpty == false {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Erkannter Text", systemImage: "text.alignleft")
                            .font(.headline)
                        Text(appointment.recognizedText)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(surfaceBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(surfaceBorder, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Termin")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingFullScreenImage) {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let image = ScannedImageStore.shared.loadImage(filename: appointment.imageFilename) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } else {
                        ContentUnavailableView("Kein Bild gefunden", systemImage: "photo.slash")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fertig") {
                            isShowingFullScreenImage = false
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

private struct AppointmentHeroImage: View {
    let filename: String
    let backgroundColor: Color
    let borderColor: Color

    var body: some View {
        Group {
            if let image = ScannedImageStore.shared.loadImage(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                ContentUnavailableView("Zettel fehlt", systemImage: "photo.badge.exclamationmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .background(backgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
}

private struct DetailCard: View {
    let title: String
    let systemImage: String
    let value: String
    let backgroundColor: Color
    let borderColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
}
