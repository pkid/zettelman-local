import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onComplete: (Result<UIImage, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onComplete: (Result<UIImage, Error>) -> Void

        init(onComplete: @escaping (Result<UIImage, Error>) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(.failure(ImagePickerError.cancelled))
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onComplete(.failure(ImagePickerError.missingImage))
                return
            }

            onComplete(.success(image))
        }
    }
}

enum ImagePickerError: LocalizedError, Equatable {
    case cancelled
    case missingImage

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .missingImage:
            return "The selected image could not be loaded."
        }
    }
}
