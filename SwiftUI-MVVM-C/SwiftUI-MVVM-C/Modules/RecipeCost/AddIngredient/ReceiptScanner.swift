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
            // (all item names as one block, all prices as another). Uses x-position to
            // classify each observation as a name or price column, then pairs them in order.
            if items.isEmpty {
                items = parseFromColumnBlocks(observations: observations)
            }

            // Strategy 3: Vision sometimes returns each item as two separate per-row
            // observations (name on left, price on right). Pair them by Y proximity.
            if items.isEmpty {
                items = pairByYProximity(observations: observations)
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

    // MARK: - Strategy 2: Column block pairing (x-position aware)

    /// Used when Vision treats the item-name column and price column as separate multi-line
    /// observations. Uses the horizontal midpoint of each observation to classify it as a
    /// name column (left side) or price column (right side), then pairs them in vertical order.
    private static func parseFromColumnBlocks(observations: [VNRecognizedTextObservation]) -> [ReceiptLineItem] {
        guard !observations.isEmpty else { return [] }
        guard let priceRegex = try? NSRegularExpression(pattern: #"-?\$?(\d+\.\d{2})"#) else { return [] }

        var allPrices: [Double] = []
        var allNames: [String] = []

        // Process observations top-to-bottom so names and prices stay in the same order.
        let sorted = observations
            .compactMap { obs -> (yMid: Double, xMid: Double, text: String)? in
                guard let text = obs.topCandidates(1).first?.string else { return nil }
                return (yMid: Double(obs.boundingBox.midY),
                        xMid: Double(obs.boundingBox.midX),
                        text: text)
            }
            .sorted { $0.yMid > $1.yMid }

        // Words that signal a non-item line in the price column (totals, tax, payment info).
        let priceSectionNoiseWords = [
            "total", "subtotal", "tax", "balance", "cash", "change",
            "credit", "debit", "visa", "mastercard", "amex", "discover",
            "promo", "discount", "savings", "saved", "less",
            "auth", "approval", "tid:", "mid:", "contactless",
            "purchase", "pay ", "amount", "receipt", "thank",
        ]

        for obs in sorted {
            let text = obs.text
            let range = NSRange(text.startIndex..., in: text)
            let matches = priceRegex.matches(in: text, range: range)

            // Right-side observations (midX > 0.55) that contain at least one price are
            // the price column, regardless of how many prices they have.
            let isRightSide = obs.xMid > 0.55
            let hasAnyPrice = !matches.isEmpty

            if isRightSide && hasAnyPrice {
                // Price column: process line-by-line so we can skip summary/discount/tax lines.
                let priceLines = text.components(separatedBy: .newlines)
                for line in priceLines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    let lower = trimmed.lowercased()
                    // Skip lines whose label text reveals they aren't item prices.
                    guard !priceSectionNoiseWords.contains(where: { lower.contains($0) }) else { continue }
                    // Skip discount lines (negative amounts like "-$0.65").
                    guard !trimmed.hasPrefix("-") else { continue }
                    let lineRange = NSRange(trimmed.startIndex..., in: trimmed)
                    let lineMatches = priceRegex.matches(in: trimmed, range: lineRange)
                    for match in lineMatches {
                        if let r = Range(match.range(at: 1), in: trimmed), let price = Double(trimmed[r]),
                           price > 0, price < 500 {
                            allPrices.append(price)
                        }
                    }
                }
            } else if !isRightSide && matches.isEmpty {
                // Name column: split by newlines and clean each candidate.
                let lines = text
                    .components(separatedBy: .newlines)
                    .map { cleanItemName($0) }
                    .filter { isPlausibleItemName($0) }
                allNames.append(contentsOf: lines)
            }
        }

        // Pair names with prices in order. Any excess prices (totals, tax) are ignored.
        var items: [ReceiptLineItem] = []
        for i in 0..<min(allNames.count, allPrices.count) {
            items.append(ReceiptLineItem(name: allNames[i], price: allPrices[i]))
        }
        return items
    }

    // MARK: - Strategy 3: Y-proximity pairing

    /// Used when Vision returns each receipt row as two separate observations — one for the
    /// item name (left-aligned) and one for the price (right-aligned). Matches each pure-price
    /// observation with the closest name observation at a similar vertical position.
    private static func pairByYProximity(observations: [VNRecognizedTextObservation]) -> [ReceiptLineItem] {
        guard let purePriceRegex = try? NSRegularExpression(pattern: #"^-?\$?\s*(\d+\.\d{2})\s*$"#) else { return [] }

        typealias NameEntry  = (yMid: Double, text: String)
        typealias PriceEntry = (yMid: Double, price: Double)

        var nameEntries:  [NameEntry]  = []
        var priceEntries: [PriceEntry] = []

        for obs in observations {
            guard let raw = obs.topCandidates(1).first?.string else { continue }
            let text = raw.trimmingCharacters(in: .whitespaces)
            let yMid = obs.boundingBox.midY
            let range = NSRange(text.startIndex..., in: text)

            if let match = purePriceRegex.firstMatch(in: text, range: range),
               let priceRange = Range(match.range(at: 1), in: text),
               let price = Double(text[priceRange]),
               price > 0, price < 500 {
                priceEntries.append((yMid, price))
            } else {
                let name = cleanItemName(text)
                if isPlausibleItemName(name) {
                    nameEntries.append((yMid, name))
                }
            }
        }

        guard !priceEntries.isEmpty, !nameEntries.isEmpty else { return [] }

        // For each price, find the nearest unused name within a 4 % Y window.
        var usedNames = Set<Int>()
        var pairs: [(yMid: Double, item: ReceiptLineItem)] = []

        for priceEntry in priceEntries.sorted(by: { $0.yMid > $1.yMid }) {
            var bestIdx: Int?
            var bestDist = Double.infinity
            for (i, nameEntry) in nameEntries.enumerated() {
                guard !usedNames.contains(i) else { continue }
                let dist = abs(nameEntry.yMid - priceEntry.yMid)
                if dist < bestDist && dist < 0.04 {
                    bestDist = dist
                    bestIdx = i
                }
            }
            if let idx = bestIdx {
                usedNames.insert(idx)
                pairs.append((
                    yMid: priceEntry.yMid,
                    item: ReceiptLineItem(name: nameEntries[idx].text, price: priceEntry.price)
                ))
            }
        }

        return pairs.sorted { $0.yMid > $1.yMid }.map { $0.item }
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
        // Remove trailing price if present (can happen in column-block observations)
        s = s.replacingOccurrences(of: #"\s+-?\$?\d+\.\d{2}\s*$"#, with: "", options: .regularExpression)
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
        // Reject strings that are purely a price value (e.g. "$2.60" or "2.60")
        if name.range(of: #"^-?\$?\s*\d+\.\d{2}\s*$"#, options: .regularExpression) != nil { return false }
        // Reject strings where the only non-digit content is dollar signs and decimal points
        // (e.g. "$2.60  $1.95  $3.25" — a price column mistakenly treated as a name)
        let letterCount = name.filter { $0.isLetter }.count
        if letterCount < 2 { return false }
        // Reject zip codes and lines containing them (e.g. "MADISON, AL 35756")
        if name.range(of: #"\b\d{5}\b"#, options: .regularExpression) != nil { return false }
        // Reject street address-style names starting with a house/building number
        // (e.g. "549 6TH ST,") — real item names very rarely begin with 3+ digits.
        if name.range(of: #"^\d{3,}\s"#, options: .regularExpression) != nil { return false }
        return true
    }
}
