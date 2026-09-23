//
//  BarcodeScanner.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import SwiftUI
import VisionKit

/// Wraps VisionKit's live barcode scanner. It keeps scanning until the
/// person is done, so more than one item can be picked up in one session.
/// Only the barcode number it reads ever leaves the phone, to look the
/// product up; the camera feed itself never does.
struct BarcodeScannerView: UIViewControllerRepresentable {
    /// Called once per newly-seen barcode payload.
    let onRecognize: (String) -> Void

    /// False on the Simulator, on devices without the right hardware, and
    /// when camera access hasn't been granted.
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognize: onRecognize)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onRecognize: (String) -> Void

        init(onRecognize: @escaping (String) -> Void) {
            self.onRecognize = onRecognize
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for case .barcode(let barcode) in addedItems {
                if let payload = barcode.payloadStringValue {
                    onRecognize(payload)
                }
            }
        }
    }
}
