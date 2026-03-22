import PhotosUI
import SwiftUI
import UIKit

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onComplete: (Result<UIImage, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onComplete: (Result<UIImage, Error>) -> Void

        init(onComplete: @escaping (Result<UIImage, Error>) -> Void) {
            self.onComplete = onComplete
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onComplete(.failure(ImagePickerError.cancelled))
                return
            }

            guard provider.canLoadObject(ofClass: UIImage.self) else {
                onComplete(.failure(ImagePickerError.missingImage))
                return
            }

            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    DispatchQueue.main.async {
                        self.onComplete(.failure(error))
                    }
                    return
                }

                guard let image = object as? UIImage else {
                    DispatchQueue.main.async {
                        self.onComplete(.failure(ImagePickerError.missingImage))
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.onComplete(.success(image))
                }
            }
        }
    }
}
