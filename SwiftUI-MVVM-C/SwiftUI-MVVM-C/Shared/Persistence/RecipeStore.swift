//
//  RecipeStore.swift
//  SwiftUI-MVVM-C
//

import Foundation
import SwiftData

/// Provides the shared SwiftData ModelContainer for the recipe feature.
/// Inject via `.modelContainer(RecipeStore.shared)` on the root view.
struct RecipeStore {
    static let shared: ModelContainer = {
        let schema = Schema([Recipe.self, Ingredient.self, IngredientTemplate.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
