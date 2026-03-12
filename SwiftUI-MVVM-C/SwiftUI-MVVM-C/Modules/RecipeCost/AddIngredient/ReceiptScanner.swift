//
//  ReceiptScanner.swift
//  SwiftUI-MVVM-C
//
//  Uses Vision framework for on-device OCR — no network call, no API key.
//

import Foundation
import Vision
import UIKit

struct ReceiptLineItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
}

enum ReceiptScannerError: LocalizedError {
    case noTextFound
    case processingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text could be read from the image."
        case .processingFailed(let e):
            return e.localizedDescription
        }
    }
}

struct ReceiptScanner {
    /// Runs OCR on the provided UIImage and returns parsed line items.
    /// Call from a background thread; calls back on main queue.
    static func scan(image: UIImage, completion: @escaping (Result<[ReceiptLineItem], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async { completion(.failure(ReceiptScannerError.noTextFound)) }
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(ReceiptScannerError.processingFailed(error))) }
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let items = parseLineItems(from: lines)

            DispatchQueue.main.async {
                if items.isEmpty {
                    completion(.failure(ReceiptScannerError.noTextFound))
                } else {
                    completion(.success(items))
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(ReceiptScannerError.processingFailed(error))) }
            }
        }
    }

    // MARK: - Parsing

    /// Parses OCR lines looking for patterns like "Item Name   $4.99" or "Item Name   4.99"
    private static func parseLineItems(from lines: [String]) -> [ReceiptLineItem] {
        // Regex: optional $, then digits.digits at the end of the line
        let pricePattern = #"^(.+?)\s+\$?(\d+\.\d{2})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pricePattern) else { return [] }

        var items: [ReceiptLineItem] = []

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            guard let nameRange = Range(match.range(at: 1), in: line),
                  let priceRange = Range(match.range(at: 2), in: line),
                  let price = Double(line[priceRange]) else { continue }

            let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)

            // Filter out common receipt non-items (tax, total, subtotal, change, etc.)
            let lowercased = name.lowercased()
            let skipWords = ["total", "subtotal", "tax", "change", "balance", "cash", "credit", "debit", "visa", "mastercard", "thank"]
            guard !skipWords.contains(where: { lowercased.contains($0) }) else { continue }
            guard price > 0 && price < 1000 else { continue }

            items.append(ReceiptLineItem(name: name, price: price))
        }

        return items
    }
}
