//
//  AddIngredientViewModel.swift
//  SwiftUI-MVVM-C
//

import Foundation
import Combine
import SwiftData

@MainActor
class AddIngredientViewModel: ObservableObject {
    // MARK: - Manual entry fields
    @Published var name = ""
    @Published var purchaseCost = ""
    @Published var purchaseQuantity = ""
    @Published var purchaseUnit = "oz"
    @Published var recipeQuantity = ""
    @Published var recipeUnit = "oz"

    // MARK: - Kroger search
    @Published var searchQuery = ""
    @Published var searchResults: [KrogerProduct] = []
    @Published var isSearching = false
    @Published var searchError: String?
    @Published var confirmedPrice: Double?

    // MARK: - State
    @Published var activeTab: AddIngredientTab = .manual

    var networkClient: GroceryNetworkProvider = GroceryNetworkClient()
    private var cancellables = Set<AnyCancellable>()

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(purchaseCost) != nil &&
        Double(purchaseQuantity) != nil &&
        Double(recipeQuantity) != nil
    }

    func searchProducts() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        searchError = nil
        networkClient.searchProducts(query: query)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isSearching = false
                if case .failure(let error) = completion {
                    self?.searchError = error.localizedDescription
                }
            }, receiveValue: { [weak self] products in
                self?.searchResults = products
            })
            .store(in: &cancellables)
    }

    func selectProduct(_ product: KrogerProduct) {
        name = product.description
        if let price = product.price {
            purchaseCost = String(format: "%.2f", price)
            confirmedPrice = price
        }
        activeTab = .manual
    }

    func saveIngredient(to recipe: Recipe, context: ModelContext) {
        guard let cost = Double(purchaseCost),
              let pQty = Double(purchaseQuantity),
              let rQty = Double(recipeQuantity) else { return }

        let ingredient = Ingredient(
            name: name.trimmingCharacters(in: .whitespaces),
            purchaseCost: cost,
            purchaseQuantity: pQty,
            purchaseUnit: purchaseUnit,
            recipeQuantity: rQty,
            recipeUnit: recipeUnit
        )
        recipe.ingredients.append(ingredient)
        context.insert(ingredient)
        try? context.save()
    }

    /// Populate fields from a receipt-parsed line item for user confirmation.
    func prefillFromReceiptItem(_ item: ReceiptLineItem) {
        name = item.name
        purchaseCost = String(format: "%.2f", item.price)
        activeTab = .manual
    }
}

enum AddIngredientTab: String, CaseIterable {
    case manual = "Manual"
    case search = "Lookup Price"
    case receipt = "Scan Receipt"
}
