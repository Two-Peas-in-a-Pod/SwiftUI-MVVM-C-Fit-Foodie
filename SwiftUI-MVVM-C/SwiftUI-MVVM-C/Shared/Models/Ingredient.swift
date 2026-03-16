//
//  Ingredient.swift
//  SwiftUI-MVVM-C
//

import Foundation
import SwiftData

@Model
class Ingredient {
    var id: UUID
    var name: String
    /// Price the user paid at the store
    var purchaseCost: Double
    /// Total quantity in the purchased package (e.g. 32 for a 32 oz bottle)
    var purchaseQuantity: Double
    /// Unit for the purchased package (e.g. "oz", "g", "count")
    var purchaseUnit: String
    /// Quantity this recipe uses
    var recipeQuantity: Double
    /// Unit for the recipe amount — should match purchaseUnit
    var recipeUnit: String
    /// Whether this ingredient is taxed at the alcohol rate rather than the grocery rate
    var isAlcohol: Bool
    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        name: String,
        purchaseCost: Double,
        purchaseQuantity: Double,
        purchaseUnit: String,
        recipeQuantity: Double,
        recipeUnit: String,
        isAlcohol: Bool = false
    ) {
        self.id = id
        self.name = name
        self.purchaseCost = purchaseCost
        self.purchaseQuantity = purchaseQuantity
        self.purchaseUnit = purchaseUnit
        self.recipeQuantity = recipeQuantity
        self.recipeUnit = recipeUnit
        self.isAlcohol = isAlcohol
    }

    /// Cost attributed to this ingredient for one recipe batch.
    /// Converts purchase and recipe quantities to a common base unit before dividing,
    /// so mixed units like "4 lb purchased, 3 oz used" calculate correctly.
    var costContribution: Double {
        guard purchaseQuantity > 0 else { return 0 }
        let purchaseCat = Self.unitCategory(purchaseUnit)
        let recipeCat = Self.unitCategory(recipeUnit)
        if purchaseCat == recipeCat && purchaseCat != "count" {
            let purchaseBase = Self.toBaseUnit(purchaseQuantity, unit: purchaseUnit)
            let recipeBase = Self.toBaseUnit(recipeQuantity, unit: recipeUnit)
            guard purchaseBase > 0 else { return 0 }
            return purchaseCost * (recipeBase / purchaseBase)
        }
        // Same unit or incompatible categories — fall back to raw ratio
        return purchaseCost * (recipeQuantity / purchaseQuantity)
    }

    private static func unitCategory(_ unit: String) -> String {
        switch unit.lowercased() {
        case "oz", "lb", "g", "kg": return "weight"
        case "ml", "l", "tsp", "tbsp", "cup": return "volume"
        default: return "count"
        }
    }

    /// Converts a quantity to the category's base unit (oz for weight, ml for volume).
    private static func toBaseUnit(_ quantity: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "oz":   return quantity
        case "lb":   return quantity * 16
        case "g":    return quantity / 28.3495
        case "kg":   return quantity * 1000 / 28.3495
        case "ml":   return quantity
        case "l":    return quantity * 1000
        case "tsp":  return quantity * 4.92892
        case "tbsp": return quantity * 14.7868
        case "cup":  return quantity * 236.588
        default:     return quantity
        }
    }
}
