//
//  RecipeTextParser.swift
//  SwiftUI-MVVM-C
//

import Foundation

// MARK: - Parsed types

struct ParsedIngredient {
    var name: String
    var purchaseCost: Double
    /// Quantity in the purchased package (defaults to 1 when not specified in the paste)
    var purchaseQuantity: Double
    var purchaseUnit: String
    var recipeQuantity: Double
    var recipeUnit: String
}

struct ParsedRecipe {
    var ingredients: [ParsedIngredient]
}

// MARK: - Parser

enum RecipeTextParser {

    /// Parses a multi-line ingredient list into a `ParsedRecipe`.
    ///
    /// Each ingredient is two consecutive non-blank lines:
    /// ```
    /// Spinach, $2.35/bag
    /// Use: 1 cup
    /// ```
    /// Purchase quantity is optional — `$2.35/bag` and `$2.35/1bag` are both valid.
    /// Blank lines between pairs are ignored. Malformed pairs are skipped silently.
    static func parse(_ text: String) -> ParsedRecipe {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var ingredients: [ParsedIngredient] = []
        var i = 0
        while i < lines.count {
            guard let purchase = parsePurchaseLine(lines[i]) else { i += 1; continue }
            let nextIndex = i + 1
            guard nextIndex < lines.count, let use = parseUseLine(lines[nextIndex]) else { i += 1; continue }
            ingredients.append(ParsedIngredient(
                name: purchase.name,
                purchaseCost: purchase.cost,
                purchaseQuantity: purchase.quantity,
                purchaseUnit: purchase.unit,
                recipeQuantity: use.quantity,
                recipeUnit: use.unit
            ))
            i = nextIndex + 1
        }
        return ParsedRecipe(ingredients: ingredients)
    }

    // MARK: - Line parsers

    /// Parses `Spinach, $2.35/bag` or `Olive oil, $7.49/32oz` or `Chicken, $8.99/1 lb`
    private static func parsePurchaseLine(_ line: String)
        -> (name: String, cost: Double, quantity: Double, unit: String)?
    {
        // Pattern: NAME, $COST/QTY?UNIT
        // QTY is optional digits (with optional decimal). UNIT is one or more word chars / spaces.
        let pattern = #"^(.+?),\s*\$(\d+\.?\d*)/(\d*\.?\d*)?\s*([a-zA-Z][a-zA-Z\s]*)$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let nameRange    = Range(match.range(at: 1), in: line),
            let costRange    = Range(match.range(at: 2), in: line),
            let unitRange    = Range(match.range(at: 4), in: line),
            let cost = Double(line[costRange])
        else { return nil }

        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        let unit = String(line[unitRange]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !unit.isEmpty else { return nil }

        let qtyRange = Range(match.range(at: 3), in: line)
        let qtyStr = qtyRange.map { String(line[$0]) } ?? ""
        let quantity = qtyStr.isEmpty ? 1.0 : (Double(qtyStr) ?? 1.0)

        return (name, cost, quantity, unit)
    }

    /// Parses `Use: 1 cup` or `use: 0.5 lb`
    private static func parseUseLine(_ line: String) -> (quantity: Double, unit: String)? {
        let lower = line.lowercased()
        guard lower.hasPrefix("use:") else { return nil }
        let rest = line.dropFirst("use:".count).trimmingCharacters(in: .whitespaces)
        // Split on first whitespace: QTY UNIT
        guard let spaceIdx = rest.firstIndex(where: { $0.isWhitespace }) else { return nil }
        let qtyStr = String(rest[rest.startIndex..<spaceIdx])
        let unit = String(rest[rest.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
        guard let qty = Double(qtyStr), !unit.isEmpty else { return nil }
        return (qty, unit)
    }
}
