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
    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        name: String,
        purchaseCost: Double,
        purchaseQuantity: Double,
        purchaseUnit: String,
        recipeQuantity: Double,
        recipeUnit: String
    ) {
        self.id = id
        self.name = name
        self.purchaseCost = purchaseCost
        self.purchaseQuantity = purchaseQuantity
        self.purchaseUnit = purchaseUnit
        self.recipeQuantity = recipeQuantity
        self.recipeUnit = recipeUnit
    }

    /// Cost attributed to this ingredient for one recipe batch
    var costContribution: Double {
        guard purchaseQuantity > 0 else { return 0 }
        return purchaseCost * (recipeQuantity / purchaseQuantity)
    }
}
