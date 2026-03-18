//
//  Recipe.swift
//  SwiftUI-MVVM-C
//

import Foundation
import SwiftData

@Model
class Recipe {
    var id: UUID
    var name: String
    var servingsPerBatch: Int
    var targetCostPerServing: Double = 0
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var ingredients: [Ingredient]

    init(
        id: UUID = UUID(),
        name: String,
        servingsPerBatch: Int = 1,
        targetCostPerServing: Double = 0,
        ingredients: [Ingredient] = []
    ) {
        self.id = id
        self.name = name
        self.servingsPerBatch = servingsPerBatch
        self.targetCostPerServing = targetCostPerServing
        self.ingredients = ingredients
    }

    var totalCost: Double {
        ingredients.reduce(0) { $0 + $1.costContribution }
    }

    var costPerServing: Double {
        guard servingsPerBatch > 0 else { return totalCost }
        return totalCost / Double(servingsPerBatch)
    }
}
