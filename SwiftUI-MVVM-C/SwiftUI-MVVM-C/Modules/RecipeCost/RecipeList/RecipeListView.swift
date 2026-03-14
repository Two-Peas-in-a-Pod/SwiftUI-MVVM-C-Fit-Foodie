//
//  RecipeListView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingRecipe = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeListCell(recipe: recipe)
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isAddingRecipe = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $isAddingRecipe) {
                AddRecipeSheet()
            }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No Recipes",
                        systemImage: "fork.knife",
                        description: Text("Tap + to add your first recipe.")
                    )
                }
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        offsets.map { recipes[$0] }.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Add Recipe Sheet

private struct AddRecipeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var servingsText = "1"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipe Name")) {
                    TextField("e.g. Chocolate Chip Cookies", text: $name)
                }
                Section(header: Text("Servings per Batch")) {
                    TextField("e.g. 24", text: $servingsText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            )
        }
    }

    private func save() {
        let servings = max(1, Int(servingsText) ?? 1)
        let recipe = Recipe(name: name.trimmingCharacters(in: .whitespaces), servingsPerBatch: servings)
        modelContext.insert(recipe)
        try? modelContext.save()
        dismiss()
    }
}
