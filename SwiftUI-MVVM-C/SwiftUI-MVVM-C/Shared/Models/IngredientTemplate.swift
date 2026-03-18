//
//  IngredientTemplate.swift
//  SwiftUI-MVVM-C
//

import Foundation
import SwiftData

/// A reusable ingredient definition saved to the library.
/// When a user adds an ingredient to any recipe, the template is
/// automatically upserted so the same item can be quickly picked
/// in future recipes (with prices that can be adjusted at add-time).
@Model
class IngredientTemplate {
    var id: UUID
    var name: String
    var defaultPurchaseCost: Double
    var defaultPurchaseQuantity: Double
    var defaultPurchaseUnit: String
    var defaultRecipeUnit: String
    var isAlcohol: Bool

    init(
        id: UUID = UUID(),
        name: String,
        defaultPurchaseCost: Double = 0,
        defaultPurchaseQuantity: Double = 1,
        defaultPurchaseUnit: String = "oz",
        defaultRecipeUnit: String = "oz",
        isAlcohol: Bool = false
    ) {
        self.id = id
        self.name = name
        self.defaultPurchaseCost = defaultPurchaseCost
        self.defaultPurchaseQuantity = defaultPurchaseQuantity
        self.defaultPurchaseUnit = defaultPurchaseUnit
        self.defaultRecipeUnit = defaultRecipeUnit
        self.isAlcohol = isAlcohol
    }
}
