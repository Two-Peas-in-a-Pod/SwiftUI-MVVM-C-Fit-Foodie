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
    @Published var isAlcohol = false
    /// True once the user has explicitly dismissed the auto-detect pill for the current name.
    /// Resets to false when the name is cleared so detection can fire again on a fresh entry.
    private(set) var alcoholDismissed = false

    // MARK: - Kroger search
    @Published var searchQuery = ""
    @Published var searchResults: [KrogerProduct] = []
    @Published var isSearching = false
    @Published var searchError: String?
    @Published var confirmedPrice: Double?

    // MARK: - State
    @Published var activeTab: AddIngredientTab = .library

    var networkClient: GroceryNetworkProvider = GroceryNetworkClient(
        clientId: UserDefaults.standard.string(forKey: "krogerClientId") ?? "",
        clientSecret: UserDefaults.standard.string(forKey: "krogerClientSecret") ?? ""
    )
    private var cancellables = Set<AnyCancellable>()

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(purchaseCost) != nil &&
        Double(purchaseQuantity) != nil &&
        Double(recipeQuantity) != nil
    }

    // MARK: - Alcohol auto-detection

    /// Call whenever `name` changes. Updates `isAlcohol` based on keyword matching
    /// unless the user has already dismissed the pill for this entry session.
    func updateAlcoholDetection() {
        if name.isEmpty { alcoholDismissed = false }
        guard !alcoholDismissed else { return }
        isAlcohol = Self.detectsAlcohol(in: name)
    }

    /// User tapped ✕ on the pill — clear the flag and suppress further auto-detection
    /// until the name field is cleared.
    func dismissAlcohol() {
        isAlcohol = false
        alcoholDismissed = true
    }

    /// Returns true if the ingredient name contains a known alcohol keyword.
    static func detectsAlcohol(in name: String) -> Bool {
        let keywords: Set<String> = [
            "wine", "beer", "vodka", "whiskey", "whisky", "rum", "gin", "tequila",
            "bourbon", "champagne", "ale", "lager", "cider", "mead", "sake",
            "brandy", "liqueur", "liquor", "spirits", "prosecco", "vermouth",
            "schnapps", "port", "sherry", "stout", "pilsner", "seltzer hard",
            "hard seltzer", "kahlúa", "baileys", "aperol", "campari"
        ]
        let lower = name.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    // MARK: - Library

    func prefillFromTemplate(_ template: IngredientTemplate) {
        name = template.name
        purchaseCost = String(format: "%.2f", template.defaultPurchaseCost)
        purchaseQuantity = String(format: "%g", template.defaultPurchaseQuantity)
        purchaseUnit = template.defaultPurchaseUnit
        recipeUnit = template.defaultRecipeUnit
        isAlcohol = template.isAlcohol
        activeTab = .manual
    }

    // MARK: - Kroger search

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

    // MARK: - Receipt

    func prefillFromReceiptItem(_ item: ReceiptLineItem) {
        name = item.name
        purchaseCost = String(format: "%.2f", item.price)
        activeTab = .manual
    }

    // MARK: - Save

    func saveIngredient(to recipe: Recipe, context: ModelContext) {
        guard let cost = Double(purchaseCost),
              let pQty = Double(purchaseQuantity),
              let rQty = Double(recipeQuantity) else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        let ingredient = Ingredient(
            name: trimmedName,
            purchaseCost: cost,
            purchaseQuantity: pQty,
            purchaseUnit: purchaseUnit,
            recipeQuantity: rQty,
            recipeUnit: recipeUnit,
            isAlcohol: isAlcohol
        )
        recipe.ingredients.append(ingredient)
        context.insert(ingredient)

        // Upsert ingredient library template
        upsertTemplate(name: trimmedName, cost: cost, purchaseQty: pQty, purchaseUnit: purchaseUnit, recipeUnit: recipeUnit, isAlcohol: isAlcohol, context: context)

        try? context.save()
    }

    private func upsertTemplate(name: String, cost: Double, purchaseQty: Double, purchaseUnit: String, recipeUnit: String, isAlcohol: Bool, context: ModelContext) {
        let descriptor = FetchDescriptor<IngredientTemplate>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = try? context.fetch(descriptor).first {
            // Update with latest purchase info
            existing.defaultPurchaseCost = cost
            existing.defaultPurchaseQuantity = purchaseQty
            existing.defaultPurchaseUnit = purchaseUnit
            existing.defaultRecipeUnit = recipeUnit
            existing.isAlcohol = isAlcohol
        } else {
            let template = IngredientTemplate(
                name: name,
                defaultPurchaseCost: cost,
                defaultPurchaseQuantity: purchaseQty,
                defaultPurchaseUnit: purchaseUnit,
                defaultRecipeUnit: recipeUnit,
                isAlcohol: isAlcohol
            )
            context.insert(template)
        }
    }
}

enum AddIngredientTab: String, CaseIterable {
    case library = "Library"
    case manual = "Manual"
    case search = "Lookup Price"
    case receipt = "Scan Receipt"
}
