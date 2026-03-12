//
//  RecipeCostCoordinator.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData

struct RecipeCostCoordinator: View {
    @State private var selectedRecipe: Recipe?
    @State private var recipeForIngredient: Recipe?

    var body: some View {
        VStack {
            RecipeListView(tapOnRecipeAction: { recipe in
                selectedRecipe = recipe
            })

            if let recipe = selectedRecipe {
                EmptyNavigationLink(
                    destination: RecipeDetailView(recipe: recipe, tapAddIngredientAction: { r in
                        recipeForIngredient = r
                    }),
                    selectedItem: $selectedRecipe
                )
            }
        }
        .sheet(item: $recipeForIngredient) { recipe in
            AddIngredientView(recipe: recipe)
        }
    }
}
