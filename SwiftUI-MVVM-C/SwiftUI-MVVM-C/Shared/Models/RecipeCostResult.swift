//
//  RecipeCostResult.swift
//  SwiftUI-MVVM-C
//

import Foundation

/// Computed cost breakdown — not stored, derived from Recipe on demand.
struct RecipeCostResult {
    let totalIngredientCost: Double
    let costPerBatch: Double
    let costPerServing: Double

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()

    var formattedTotalCost: String {
        Self.formatter.string(from: NSNumber(value: totalIngredientCost)) ?? "$0.00"
    }

    var formattedCostPerServing: String {
        Self.formatter.string(from: NSNumber(value: costPerServing)) ?? "$0.00"
    }
}

extension Recipe {
    func costResult() -> RecipeCostResult {
        RecipeCostResult(
            totalIngredientCost: totalCost,
            costPerBatch: totalCost,
            costPerServing: costPerServing
        )
    }
}
