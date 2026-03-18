//
//  ReceiptScannerViewModel.swift
//  SwiftUI-MVVM-C
//

import Foundation
import UIKit
import Combine

@MainActor
class ReceiptScannerViewModel: ObservableObject {
    @Published var scannedItems: [ReceiptLineItem] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showImagePicker = false
    @Published var imagePickerSource: UIImagePickerController.SourceType = .camera

    func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        ReceiptScanner.scan(image: image) { [weak self] result in
            guard let self else { return }
            self.isProcessing = false
            switch result {
            case .success(let items):
                self.scannedItems = items
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
