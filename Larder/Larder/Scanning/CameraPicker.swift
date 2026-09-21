//
//  CameraPicker.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI
import UIKit

/// Wraps UIKit's camera screen so SwiftUI can show it. SwiftUI has no camera
/// view of its own, so a UIKit view controller is wrapped in a
/// `UIViewControllerRepresentable`, which is how SwiftUI hosts UIKit screens.
struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the photo, or nil if the person cancelled.
    let onFinish: (CGImage?) -> Void

    /// False on the Simulator and on devices without a camera.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (CGImage?) -> Void

        init(onFinish: @escaping (CGImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.originalImage] as? UIImage).flatMap(Self.upright)
            onFinish(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }

        /// Camera photos carry a rotation flag instead of being stored upright.
        /// Redrawing them bakes the rotation in, so later steps see the picture
        /// the way the person did.
        private nonisolated static func upright(_ image: UIImage) -> CGImage? {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            let redrawn = renderer.image { _ in image.draw(at: .zero) }
            return redrawn.cgImage?.downscaled(maxEdge: 2400)
        }
    }
}
