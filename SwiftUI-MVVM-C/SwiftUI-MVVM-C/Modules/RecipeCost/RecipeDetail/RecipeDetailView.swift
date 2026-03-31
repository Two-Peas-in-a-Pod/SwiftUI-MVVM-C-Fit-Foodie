//
//  RecipeDetailView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData
import UIKit

struct RecipeDetailView: View {
    @StateObject private var viewModel: RecipeDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("salesTaxRate") private var salesTaxRate: Double = 0
    @AppStorage("alcoholTaxRate") private var alcoholTaxRate: Double = 0
    @AppStorage("costGoalEnabled") private var costGoalEnabled: Bool = false
    @State private var servingsText: String
    @State private var goalText: String
    @State private var isAddingIngredient = false
    @State private var editingIngredient: Ingredient?

    init(recipe: Recipe) {
        _viewModel = StateObject(wrappedValue: RecipeDetailViewModel(recipe: recipe))
        _servingsText = State(initialValue: "\(recipe.servingsPerBatch)")
        _goalText = State(initialValue: recipe.targetCostPerServing > 0
            ? String(format: "%.2f", recipe.targetCostPerServing)
            : "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                costSummaryCard
                servingsRow
                if costGoalEnabled {
                    costGoalRow
                }
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear {
            viewModel.refreshCost()
        }
        .onChange(of: salesTaxRate) { _, _ in
            viewModel.refreshCost()
        }
        .onChange(of: alcoholTaxRate) { _, _ in
            viewModel.refreshCost()
        }
        .sheet(isPresented: $isAddingIngredient, onDismiss: {
            viewModel.refreshCost()
        }) {
            AddIngredientView(recipe: viewModel.recipe)
        }
        .sheet(item: $editingIngredient, onDismiss: {
            viewModel.refreshCost()
        }) { ingredient in
            EditIngredientSheet(ingredient: ingredient)
        }
    }

    // MARK: - Subviews

    /// nil when cost goal is disabled, no goal set, or feature is turned off in settings.
    private var budgetIndicatorColor: Color? {
        guard costGoalEnabled else { return nil }
        let target = viewModel.recipe.targetCostPerServing
        guard target > 0 else { return nil }
        let actual = viewModel.costResult.costPerServingWithTax
        if actual <= target { return .green }
        if actual <= target * 1.25 { return .orange }
        return .red
    }

    private var costSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                costItem(label: "Total Cost", value: viewModel.costResult.formattedTotalCost)
                Divider()
                VStack(spacing: 4) {
                    Text("Per Serving")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 5) {
                        Text(viewModel.costResult.formattedCostPerServing)
                            .font(.title2)
                            .fontWeight(.semibold)
                        if let color = budgetIndicatorColor {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            if viewModel.costResult.hasTax {
                Divider()
                HStack {
                    Text("Subtotal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.costResult.formattedSubtotal)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if viewModel.costResult.groceryTaxAmount > 0 {
                    HStack {
                        Text("Grocery Tax (\(String(format: "%g", salesTaxRate))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.costResult.formattedGroceryTaxAmount)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if viewModel.costResult.alcoholTaxAmount > 0 {
                    HStack {
                        Text("Alcohol Tax (\(String(format: "%g", alcoholTaxRate))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.costResult.formattedAlcoholTaxAmount)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
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

    private var costGoalRow: some View {
        HStack {
            Text("Cost goal per serving")
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                Text("$")
                    .foregroundColor(.secondary)
                TextField("None", text: $goalText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: goalText) { _, newValue in
                        viewModel.recipe.targetCostPerServing = Double(newValue) ?? 0
                        try? modelContext.save()
                    }
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
                HStack(spacing: 6) {
                    Text(ingredient.name)
                        .font(.subheadline)
                    if ingredient.isAlcohol {
                        Text("Alcohol")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                }
                Text("\(ingredient.recipeQuantity.formatted()) \(ingredient.recipeUnit) used")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Purchased: \(String(format: "$%.2f", ingredient.purchaseCost)) for \(ingredient.purchaseQuantity.formatted()) \(ingredient.purchaseUnit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "$%.2f", ingredient.costContribution))
                .font(.subheadline)
                .fontWeight(.medium)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            editingIngredient = ingredient
        }
        .contextMenu {
            Button { editingIngredient = ingredient } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.deleteIngredient(ingredient, from: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Edit Ingredient Sheet

private struct EditIngredientSheet: View {
    let ingredient: Ingredient
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alcoholTaxRate") private var alcoholTaxRate: Double = 0

    @State private var name: String
    @State private var purchaseCost: String
    @State private var purchaseQuantity: String
    @State private var purchaseUnit: String
    @State private var recipeQuantity: String
    @State private var recipeUnit: String
    @State private var isAlcohol: Bool
    @State private var alcoholDismissed: Bool

    private let units = ["oz", "fl oz", "g", "kg", "lb", "cup", "tbsp", "tsp", "ml", "L", "count"]

    init(ingredient: Ingredient) {
        self.ingredient = ingredient
        _name = State(initialValue: ingredient.name)
        _purchaseCost = State(initialValue: String(format: "%.2f", ingredient.purchaseCost))
        _purchaseQuantity = State(initialValue: String(format: "%g", ingredient.purchaseQuantity))
        _purchaseUnit = State(initialValue: ingredient.purchaseUnit)
        _recipeQuantity = State(initialValue: String(format: "%g", ingredient.recipeQuantity))
        _recipeUnit = State(initialValue: ingredient.recipeUnit)
        _isAlcohol = State(initialValue: ingredient.isAlcohol)
        _alcoholDismissed = State(initialValue: false)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(purchaseCost) != nil &&
        Double(purchaseQuantity) != nil &&
        Double(recipeQuantity) != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ingredient")) {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, newName in
                            if newName.isEmpty { alcoholDismissed = false }
                            if !alcoholDismissed {
                                isAlcohol = AddIngredientViewModel.detectsAlcohol(in: newName)
                            }
                        }
                    if alcoholTaxRate > 0 && isAlcohol {
                        HStack {
                            Label("Alcohol tax will apply", systemImage: "wineglass")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Spacer()
                            Button {
                                isAlcohol = false
                                alcoholDismissed = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.purple.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.purple.opacity(0.08))
                    }
                }
                Section(header: Text("Purchase Info — what you bought at the store")) {
                    HStack {
                        Text("Cost ($)")
                        Spacer()
                        TextField("e.g. 6.99", text: $purchaseCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("e.g. 32", text: $purchaseQuantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Unit", selection: $purchaseUnit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section(header: Text("Recipe Usage — how much this recipe calls for")) {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("e.g. 2", text: $recipeQuantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Unit", selection: $recipeUnit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle("Edit Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private func save() {
        guard let cost = Double(purchaseCost),
              let pQty = Double(purchaseQuantity),
              let rQty = Double(recipeQuantity) else { return }
        ingredient.name = name.trimmingCharacters(in: .whitespaces)
        ingredient.purchaseCost = cost
        ingredient.purchaseQuantity = pQty
        ingredient.purchaseUnit = purchaseUnit
        ingredient.recipeQuantity = rQty
        ingredient.recipeUnit = recipeUnit
        ingredient.isAlcohol = isAlcohol
        try? modelContext.save()
        dismiss()
    }
}
