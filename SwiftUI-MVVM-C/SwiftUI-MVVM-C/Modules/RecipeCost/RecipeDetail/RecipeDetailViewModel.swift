//
//  RecipeDetailViewModel.swift
//  SwiftUI-MVVM-C
//

import Foundation
import SwiftData
import Combine

@MainActor
class RecipeDetailViewModel: ObservableObject {
    @Published var recipe: Recipe
    @Published var costResult: RecipeCostResult

    init(recipe: Recipe) {
        self.recipe = recipe
        self.costResult = recipe.costResult(taxRate: Self.currentTaxRate)
    }

    func refreshCost() {
        costResult = recipe.costResult(
            groceryTaxRate: Self.groceryTaxRate,
            alcoholTaxRate: Self.alcoholTaxRate
        )
    }

    private static var groceryTaxRate: Double {
        UserDefaults.standard.double(forKey: "salesTaxRate") / 100.0
    }

    private static var alcoholTaxRate: Double {
        UserDefaults.standard.double(forKey: "alcoholTaxRate") / 100.0
    }

    func deleteIngredient(_ ingredient: Ingredient, from context: ModelContext) {
        recipe.ingredients.removeAll { $0.id == ingredient.id }
        context.delete(ingredient)
        try? context.save()
        refreshCost()
    }

    func deleteIngredients(at offsets: IndexSet, from context: ModelContext) {
        let toDelete = offsets.map { recipe.ingredients[$0] }
        toDelete.forEach { context.delete($0) }
        try? context.save()
        refreshCost()
    }

    func updateServings(_ servingsText: String, in context: ModelContext) {
        guard let s = Int(servingsText), s > 0 else { return }
        recipe.servingsPerBatch = s
        try? context.save()
        refreshCost()
    }
}
