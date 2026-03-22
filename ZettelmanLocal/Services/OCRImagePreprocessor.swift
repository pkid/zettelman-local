import CoreImage
import Foundation
import UIKit
@preconcurrency import Vision

struct OCRPreparedImage {
    let cgImage: CGImage
    let rotationLabel: String
    let wasCropped: Bool
}

struct OCRImagePreprocessor {
    private let ciContext = CIContext(options: nil)

    func prepareCandidates(from image: UIImage) -> [OCRPreparedImage] {
        guard let baseCGImage = image.normalizedForVision().cgImage else {
            return []
        }

        let baseImage = CIImage(cgImage: baseCGImage)
        let variants: [(name: String, image: CIImage)] = [
            ("0", baseImage),
            ("90", baseImage.oriented(.right)),
            ("180", baseImage.oriented(.down)),
            ("270", baseImage.oriented(.left))
        ]

        var prepared: [OCRPreparedImage] = []

        for variant in variants {
            let cropped = perspectiveCorrectedImage(from: variant.image)
            let variantImages: [(CIImage, Bool)] = {
                if let cropped {
                    return [(enhance(cropped), true), (enhance(variant.image), false)]
                }
                return [(enhance(variant.image), false)]
            }()

            for (candidate, wasCropped) in variantImages {
                guard let cgImage = ciContext.createCGImage(candidate, from: candidate.extent) else {
                    continue
                }
                prepared.append(
                    OCRPreparedImage(
                        cgImage: cgImage,
                        rotationLabel: variant.name,
                        wasCropped: wasCropped
                    )
                )
            }
        }

        return prepared
    }

    private func enhance(_ image: CIImage) -> CIImage {
        let monochrome = image.applyingFilter(
            "CIColorControls",
            parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.28,
                kCIInputBrightnessKey: 0.02
            ]
        )

        return monochrome.applyingFilter(
            "CISharpenLuminance",
            parameters: [
                kCIInputSharpnessKey: 0.45
            ]
        )
    }

    private func perspectiveCorrectedImage(from image: CIImage) -> CIImage? {
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            return nil
        }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.45
        request.minimumSize = 0.25
        request.minimumAspectRatio = 0.2
        request.quadratureTolerance = 35

        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = (request.results ?? []).max(by: { area(of: $0) < area(of: $1) }) else {
            return nil
        }

        let extent = image.extent
        let topLeft = imagePoint(for: observation.topLeft, in: extent)
        let topRight = imagePoint(for: observation.topRight, in: extent)
        let bottomLeft = imagePoint(for: observation.bottomLeft, in: extent)
        let bottomRight = imagePoint(for: observation.bottomRight, in: extent)

        let corrected = image.applyingFilter(
            "CIPerspectiveCorrection",
            parameters: [
                "inputTopLeft": CIVector(cgPoint: topLeft),
                "inputTopRight": CIVector(cgPoint: topRight),
                "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                "inputBottomRight": CIVector(cgPoint: bottomRight)
            ]
        )

        return corrected.extent.isEmpty ? nil : corrected
    }

    private func imagePoint(for normalizedPoint: CGPoint, in extent: CGRect) -> CGPoint {
        CGPoint(
            x: extent.minX + (normalizedPoint.x * extent.width),
            y: extent.minY + (normalizedPoint.y * extent.height)
        )
    }

    private func area(of observation: VNRectangleObservation) -> CGFloat {
        let width = hypot(observation.topLeft.x - observation.topRight.x, observation.topLeft.y - observation.topRight.y)
        let height = hypot(observation.topLeft.x - observation.bottomLeft.x, observation.topLeft.y - observation.bottomLeft.y)
        return width * height
    }
}

extension UIImage {
    func normalizedForVision() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
