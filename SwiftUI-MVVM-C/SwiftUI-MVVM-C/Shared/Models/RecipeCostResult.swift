//
//  RecipeCostResult.swift
//  SwiftUI-MVVM-C
//

import Foundation

/// Computed cost breakdown — not stored, derived from Recipe on demand.
struct RecipeCostResult {
    let totalIngredientCost: Double  // pre-tax subtotal
    let costPerBatch: Double
    let costPerServing: Double
    /// Fractional tax rate (e.g. 0.085 for 8.5%)
    let taxRate: Double

    var taxAmount: Double { totalIngredientCost * taxRate }
    var totalWithTax: Double { totalIngredientCost + taxAmount }
    var costPerServingWithTax: Double { costPerServing * (1 + taxRate) }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()

    private static func fmt(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    var formattedSubtotal: String { Self.fmt(totalIngredientCost) }
    var formattedTaxAmount: String { Self.fmt(taxAmount) }
    var formattedTotalCost: String { Self.fmt(totalWithTax) }
    var formattedCostPerServing: String { Self.fmt(costPerServingWithTax) }
}

extension Recipe {
    func costResult(taxRate: Double = 0) -> RecipeCostResult {
        RecipeCostResult(
            totalIngredientCost: totalCost,
            costPerBatch: totalCost,
            costPerServing: costPerServing,
            taxRate: taxRate
        )
    }
}
