//
//  ReceiptScannerView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI

struct ReceiptScannerView: View {
    @StateObject private var viewModel = ReceiptScannerViewModel()
    let onSelectItem: (ReceiptLineItem) -> Void

    var body: some View {
        VStack(spacing: 16) {
            captureButtons

            if viewModel.isProcessing {
                ProgressView("Reading receipt...")
                    .padding()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if !viewModel.scannedItems.isEmpty {
                scannedItemsList
            } else {
                Text("Snap a photo of your receipt and the app will read the items and prices for you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(sourceType: viewModel.imagePickerSource) { image in
                viewModel.processImage(image)
            }
        }
    }

    private var captureButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.imagePickerSource = .camera
                viewModel.showImagePicker = true
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            Button {
                viewModel.imagePickerSource = .photoLibrary
                viewModel.showImagePicker = true
            } label: {
                Label("Choose Photo", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var scannedItemsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap an item to add it as an ingredient:")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.scannedItems) { item in
                        Button {
                            onSelectItem(item)
                        } label: {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .leadingAlignment()
                                Spacer()
                                Text(String(format: "$%.2f", item.price))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - UIImagePickerController wrapper

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        init(onImagePicked: @escaping (UIImage) -> Void) { self.onImagePicked = onImagePicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
