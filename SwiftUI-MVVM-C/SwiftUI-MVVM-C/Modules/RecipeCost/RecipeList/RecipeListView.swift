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
    @State private var isShowingSettings = false

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { isShowingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
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
            .sheet(isPresented: $isShowingSettings) {
                CostSettingsSheet()
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

// MARK: - Cost Settings

private struct CostSettingsSheet: View {
    @AppStorage("salesTaxRate") private var salesTaxRate: Double = 0
    @Environment(\.dismiss) private var dismiss
    @State private var taxText = ""

    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Sales Tax"),
                    footer: Text("Enter the tax rate you pay on groceries. This is added on top of ingredient costs. Leave at 0 if groceries aren't taxed in your area.")
                ) {
                    HStack {
                        TextField("e.g. 8.5", text: $taxText)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    salesTaxRate = Double(taxText) ?? 0
                    dismiss()
                }
            )
            .onAppear {
                taxText = salesTaxRate == 0 ? "" : String(format: "%g", salesTaxRate)
            }
        }
    }
}
