//
//  RecipeDetailView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @StateObject private var viewModel: RecipeDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var servingsText: String
    @State private var isAddingIngredient = false

    init(recipe: Recipe) {
        _viewModel = StateObject(wrappedValue: RecipeDetailViewModel(recipe: recipe))
        _servingsText = State(initialValue: "\(recipe.servingsPerBatch)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                costSummaryCard
                servingsRow
                ingredientsList
            }
            .padding()
        }
        .navigationTitle(viewModel.recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddingIngredient = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            viewModel.refreshCost()
        }
        .sheet(isPresented: $isAddingIngredient, onDismiss: {
            viewModel.refreshCost()
        }) {
            AddIngredientView(recipe: viewModel.recipe)
        }
    }

    // MARK: - Subviews

    private var costSummaryCard: some View {
        HStack {
            costItem(label: "Total Cost", value: viewModel.costResult.formattedTotalCost)
            Divider()
            costItem(label: "Per Serving", value: viewModel.costResult.formattedCostPerServing)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func costItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }

    private var servingsRow: some View {
        HStack {
            Text("Servings per batch")
                .font(.subheadline)
            Spacer()
            TextField("1", text: $servingsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: servingsText) { _, newValue in
                    viewModel.updateServings(newValue, in: modelContext)
                }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients")
                .font(.headline)
                .leadingAlignment()

            if viewModel.recipe.ingredients.isEmpty {
                Text("No ingredients yet. Tap + to add one.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.recipe.ingredients) { ingredient in
                    ingredientRow(ingredient)
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                    .font(.subheadline)
                Text("\(ingredient.recipeQuantity.formatted()) \(ingredient.recipeUnit) used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Purchased: \(String(format: "$%.2f", ingredient.purchaseCost)) for \(ingredient.purchaseQuantity.formatted()) \(ingredient.purchaseUnit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "$%.4f", ingredient.costContribution))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
