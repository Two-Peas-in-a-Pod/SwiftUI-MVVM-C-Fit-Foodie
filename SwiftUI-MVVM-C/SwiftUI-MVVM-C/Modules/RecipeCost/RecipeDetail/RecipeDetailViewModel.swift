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
    @Published var isAddingIngredient = false
    @Published var costResult: RecipeCostResult

    init(recipe: Recipe) {
        self.recipe = recipe
        self.costResult = recipe.costResult()
    }

    func refreshCost() {
        costResult = recipe.costResult()
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
