//
//  RecipeListViewModel.swift
//  SwiftUI-MVVM-C
//

import Foundation
import SwiftData
import Combine

@MainActor
class RecipeListViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isAddingRecipe = false
    @Published var newRecipeName = ""
    @Published var newRecipeServings = "1"

    func loadRecipes(from context: ModelContext) {
        let descriptor = FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.name)])
        recipes = (try? context.fetch(descriptor)) ?? []
    }

    func addRecipe(to context: ModelContext) {
        guard !newRecipeName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let servings = Int(newRecipeServings) ?? 1
        let recipe = Recipe(name: newRecipeName.trimmingCharacters(in: .whitespaces), servingsPerBatch: max(1, servings))
        context.insert(recipe)
        try? context.save()
        newRecipeName = ""
        newRecipeServings = "1"
        isAddingRecipe = false
        loadRecipes(from: context)
    }

    func deleteRecipes(at offsets: IndexSet, from context: ModelContext) {
        offsets.forEach { index in
            context.delete(recipes[index])
        }
        try? context.save()
        loadRecipes(from: context)
    }
}
