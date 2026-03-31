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
        let schema = Schema([Recipe.self, Ingredient.self, IngredientTemplate.self, MealPlanEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed — delete the old store and retry so the app
            // doesn't crash during development.  In production you'd use
            // a VersionedSchema + SchemaMigrationPlan instead.
            let storeURL = config.url
            let base = storeURL.deletingPathExtension()
            let ext = storeURL.pathExtension
            for suffix in ["", "-wal", "-shm"] {
                let url = base.appendingPathExtension(ext + suffix)
                try? FileManager.default.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer after resetting store: \(error)")
            }
        }
    }()
}
