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
            return "No text could be read from the image. Make sure the receipt is well-lit and the text is in focus."
        case .processingFailed(let e):
            return e.localizedDescription
        }
    }
}

struct ReceiptScanner {
    /// Runs OCR on the provided UIImage and returns parsed line items.
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

            // Strategy 1: group observations that share the same vertical position into
            // full receipt lines ("ITEM NAME   $4.99"), then parse.
            // Works when Vision returns one observation per text region on each row.
            let reconstructed = reconstructLines(from: observations)
            var items = parseLineItems(from: reconstructed)

            // Strategy 2: Vision sometimes returns entire columns as a single observation
            // (all item names as one block, all prices as another). In that case strategy 1
            // produces no results, so fall back to pairing name-column and price-column blocks.
            if items.isEmpty {
                items = parseFromColumnBlocks(observations: observations)
            }

            DispatchQueue.main.async {
                if items.isEmpty {
                    completion(.failure(ReceiptScannerError.noTextFound))
                } else {
                    completion(.success(items))
                }
            }
        }

        request.recognitionLevel = .accurate
        // Disable language correction: receipt text contains barcodes, store codes, and
        // abbreviations that language correction silently mangles (e.g. "PK DRK STKS").
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(ReceiptScannerError.processingFailed(error))) }
            }
        }
    }

    // MARK: - Strategy 1: Spatial line reconstruction

    /// Groups Vision text observations by vertical midpoint so that an item name and its
    /// right-aligned price (returned as separate observations) are joined into one string
    /// before parsing. Observations within 2 % of each other's Y position are treated as
    /// the same line and sorted left-to-right.
    private static func reconstructLines(from observations: [VNRecognizedTextObservation]) -> [String] {
        guard !observations.isEmpty else { return [] }
        let tolerance = 0.02
        typealias Fragment = (xMin: Double, text: String)
        var groups: [(yMid: Double, fragments: [Fragment])] = []

        for obs in observations {
            guard let text = obs.topCandidates(1).first?.string else { continue }
            let yMid = obs.boundingBox.midY
            let xMin = obs.boundingBox.minX
            if let idx = groups.firstIndex(where: { abs($0.yMid - yMid) < tolerance }) {
                groups[idx].fragments.append((xMin, text))
            } else {
                groups.append((yMid: yMid, fragments: [(xMin, text)]))
            }
        }
        // Sort top-to-bottom (Vision Y origin is bottom-left; higher Y = higher on page).
        groups.sort { $0.yMid > $1.yMid }
        return groups.map { group in
            group.fragments.sorted { $0.xMin < $1.xMin }.map { $0.text }.joined(separator: "   ")
        }
    }

    // MARK: - Strategy 2: Column block pairing

    /// Used when Vision treats the item-name column and price column as separate multi-line
    /// observations. Identifies observations that are price-heavy (≥ 3 prices) and pairs
    /// them with the item names extracted from the remaining observations.
    private static func parseFromColumnBlocks(observations: [VNRecognizedTextObservation]) -> [ReceiptLineItem] {
        guard !observations.isEmpty else { return [] }
        guard let priceRegex = try? NSRegularExpression(pattern: #"\$?(\d+\.\d{2})"#) else { return [] }

        var allPrices: [Double] = []
        var allNames: [String] = []

        // Process observations top-to-bottom so names and prices stay in the same order.
        let sorted = observations
            .compactMap { obs -> (yMid: Double, text: String)? in
                guard let text = obs.topCandidates(1).first?.string else { return nil }
                return (yMid: Double(obs.boundingBox.midY), text: text)
            }
            .sorted { $0.yMid > $1.yMid }

        for obs in sorted {
            let text = obs.text
            let range = NSRange(text.startIndex..., in: text)
            let matches = priceRegex.matches(in: text, range: range)

            if matches.count >= 3 {
                // Price-column block: collect all individual item prices (skip totals/tax by
                // deferring filtering to the pairing step — excess prices just won't be paired).
                for match in matches {
                    if let r = Range(match.range(at: 1), in: text), let price = Double(text[r]),
                       price > 0, price < 500 {
                        allPrices.append(price)
                    }
                }
            } else if matches.isEmpty {
                // Name-column block: split by newlines and clean each candidate.
                let lines = text
                    .components(separatedBy: .newlines)
                    .map { cleanItemName($0) }
                    .filter { isPlausibleItemName($0) }
                allNames.append(contentsOf: lines)
            }
            // Observations with 1–2 prices are ambiguous (could be subtotal lines);
            // skip them to avoid polluting either list.
        }

        // Pair names with prices in order. Any excess prices (totals, tax) at the end
        // are ignored because min() stops at the shorter list.
        var items: [ReceiptLineItem] = []
        for i in 0..<min(allNames.count, allPrices.count) {
            items.append(ReceiptLineItem(name: allNames[i], price: allPrices[i]))
        }
        return items
    }

    // MARK: - Line-item parsing (used by strategy 1)

    private static func parseLineItems(from lines: [String]) -> [ReceiptLineItem] {
        // Matches optional leading tax-code letter, item name, optional barcode, price,
        // optional trailing single-letter tax code.
        // E.g.: "N SPRITE ZERO   49000037197   $2.60"
        //        "BACON                         3.99 F"
        let pattern = #"^(?:[A-Z]\s+)?(.+?)\s+(?:\d{6,}\s+)?\$?(\d+\.\d{2})(?:\s+[A-Za-z])?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var items: [ReceiptLineItem] = []
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let nameRange = Range(match.range(at: 1), in: line),
                  let priceRange = Range(match.range(at: 2), in: line),
                  let price = Double(line[priceRange]) else { continue }

            let name = cleanItemName(String(line[nameRange]))
            guard isPlausibleItemName(name), price > 0, price < 500 else { continue }
            items.append(ReceiptLineItem(name: name, price: price))
        }
        return items
    }

    // MARK: - Shared helpers

    /// Strips common receipt noise from a raw OCR string to produce a clean ingredient name.
    private static func cleanItemName(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        // Remove a leading single-letter tax code ("N ", "T ", "F ")
        if s.count > 2, s[s.index(after: s.startIndex)] == " ",
           let first = s.first, first.isLetter, first.isUppercase {
            s = String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        // Remove trailing barcodes (6 or more consecutive digits at end of string)
        s = s.replacingOccurrences(of: #"\s+\d{6,}\s*$"#, with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Returns true if the string looks like a real item name rather than a header,
    /// footer, total line, address, or other receipt noise.
    private static func isPlausibleItemName(_ name: String) -> Bool {
        guard name.count > 2 else { return false }
        let lower = name.lowercased()
        let skipWords = [
            "total", "subtotal", "tax", "change", "balance", "cash",
            "credit", "debit", "visa", "mastercard", "amex", "discover",
            "thank", "sale", "transaction", "store #", "receipt",
            "phone", "promo", "discount", "savings", "saved",
            "auth", "approval", "tid:", "mid:", "contactless",
        ]
        if skipWords.contains(where: { lower.contains($0) }) { return false }
        // Skip lines that are mostly digits and punctuation (phone numbers, barcodes, addresses)
        let nonDigitCount = name.filter { !$0.isNumber && !$0.isPunctuation && !$0.isWhitespace }.count
        if nonDigitCount < 2 { return false }
        return true
    }
}
