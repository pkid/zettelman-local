import Foundation
import UIKit

@MainActor
struct ScannedImageStore {
    static let shared = ScannedImageStore()

    func save(image: UIImage) throws -> String {
        let normalizedImage = image.normalizedForStorage()
        guard let imageData = normalizedImage.jpegData(compressionQuality: 0.88) else {
            throw ScannedImageStoreError.failedToEncodeImage
        }

        let filename = "zettel-\(UUID().uuidString).jpg"
        let destinationURL = try imageURL(for: filename)
        try imageData.write(to: destinationURL, options: .atomic)
        return filename
    }

    func delete(filename: String) {
        guard let imageURL = try? imageURL(for: filename) else {
            return
        }

        try? FileManager.default.removeItem(at: imageURL)
    }

    func loadImage(filename: String) -> UIImage? {
        guard let imageURL = try? imageURL(for: filename) else {
            return nil
        }

        return UIImage(contentsOfFile: imageURL.path)
    }

    func localURL(filename: String) -> URL? {
        try? imageURL(for: filename)
    }

    private func imageURL(for filename: String) throws -> URL {
        let directory = try storageDirectory()
        return directory.appendingPathComponent(filename)
    }

    private func storageDirectory() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = baseURL.appendingPathComponent("ScannedZettel", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

enum ScannedImageStoreError: LocalizedError {
    case failedToEncodeImage

    var errorDescription: String? {
        switch self {
        case .failedToEncodeImage:
            return "The scanned note could not be stored locally."
        }
    }
}

private extension UIImage {
    func normalizedForStorage() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
