//
//  RecipeCostResult.swift
//  SwiftUI-MVVM-C
//

import Foundation

/// Computed cost breakdown — not stored, derived from Recipe on demand.
struct RecipeCostResult {
    let subtotal: Double             // pre-tax total
    let groceryTaxAmount: Double
    let alcoholTaxAmount: Double
    let costPerServingWithTax: Double
    /// Fractional grocery tax rate (e.g. 0.085 for 8.5%) — used for display
    let groceryTaxRate: Double
    /// Fractional alcohol tax rate — used for display
    let alcoholTaxRate: Double

    var taxAmount: Double { groceryTaxAmount + alcoholTaxAmount }
    var totalWithTax: Double { subtotal + taxAmount }
    var hasTax: Bool { taxAmount > 0 }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()

    private static func fmt(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    var formattedSubtotal: String          { Self.fmt(subtotal) }
    var formattedGroceryTaxAmount: String  { Self.fmt(groceryTaxAmount) }
    var formattedAlcoholTaxAmount: String  { Self.fmt(alcoholTaxAmount) }
    var formattedTaxAmount: String         { Self.fmt(taxAmount) }
    var formattedTotalCost: String         { Self.fmt(totalWithTax) }
    var formattedCostPerServing: String    { Self.fmt(costPerServingWithTax) }
}

extension Recipe {
    func costResult(groceryTaxRate: Double = 0, alcoholTaxRate: Double = 0) -> RecipeCostResult {
        costResult(onHandIds: [], groceryTaxRate: groceryTaxRate, alcoholTaxRate: alcoholTaxRate)
    }

    /// Returns a cost result excluding ingredients whose IDs are in `onHandIds`.
    /// Used by the meal plan to calculate how much still needs to be purchased.
    func costResult(onHandIds: Set<String>, groceryTaxRate: Double = 0, alcoholTaxRate: Double = 0) -> RecipeCostResult {
        let buyIngredients = onHandIds.isEmpty ? ingredients : ingredients.filter { !onHandIds.contains($0.id.uuidString) }
        let groceryCost = buyIngredients.filter { !$0.isAlcohol }.reduce(0) { $0 + $1.costContribution }
        let alcoholCost = buyIngredients.filter { $0.isAlcohol }.reduce(0) { $0 + $1.costContribution }
        let subtotal = groceryCost + alcoholCost
        let groceryTax = groceryCost * groceryTaxRate
        let alcoholTax = alcoholCost * alcoholTaxRate
        let total = subtotal + groceryTax + alcoholTax
        let perServing = servingsPerBatch > 0 ? total / Double(servingsPerBatch) : total
        return RecipeCostResult(
            subtotal: subtotal,
            groceryTaxAmount: groceryTax,
            alcoholTaxAmount: alcoholTax,
            costPerServingWithTax: perServing,
            groceryTaxRate: groceryTaxRate,
            alcoholTaxRate: alcoholTaxRate
        )
    }
}
