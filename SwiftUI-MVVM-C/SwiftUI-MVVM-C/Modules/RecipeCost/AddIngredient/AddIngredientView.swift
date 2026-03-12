//
//  AddIngredientView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData

struct AddIngredientView: View {
    @StateObject private var viewModel = AddIngredientViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    private let units = ["oz", "g", "kg", "lb", "cup", "tbsp", "tsp", "ml", "L", "count"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Mode", selection: $viewModel.activeTab) {
                    ForEach(AddIngredientTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch viewModel.activeTab {
                case .manual:
                    manualEntryForm
                case .search:
                    krogerSearchView
                case .receipt:
                    ReceiptScannerView { item in
                        viewModel.prefillFromReceiptItem(item)
                    }
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Group {
                    if viewModel.activeTab == .manual {
                        Button("Save") {
                            viewModel.saveIngredient(to: recipe, context: modelContext)
                            dismiss()
                        }
                        .disabled(!viewModel.isFormValid)
                    }
                }
            )
        }
    }

    // MARK: - Manual Entry

    private var manualEntryForm: some View {
        Form {
            Section(header: Text("Ingredient")) {
                TextField("Name (e.g. Olive Oil)", text: $viewModel.name)
            }

            Section(header: Text("Purchase Info — what you bought at the store")) {
                HStack {
                    Text("Cost ($)")
                    Spacer()
                    TextField("e.g. 6.99", text: $viewModel.purchaseCost)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Quantity")
                    Spacer()
                    TextField("e.g. 32", text: $viewModel.purchaseQuantity)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Unit", selection: $viewModel.purchaseUnit) {
                    ForEach(units, id: \.self) { Text($0).tag($0) }
                }
            }

            Section(header: Text("Recipe Usage — how much this recipe calls for")) {
                HStack {
                    Text("Quantity")
                    Spacer()
                    TextField("e.g. 2", text: $viewModel.recipeQuantity)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Unit", selection: $viewModel.recipeUnit) {
                    ForEach(units, id: \.self) { Text($0).tag($0) }
                }
            }

            if let confirmed = viewModel.confirmedPrice {
                Section(header: Text("Price Confirmation")) {
                    HStack {
                        Text("Price from Kroger lookup:")
                        Spacer()
                        Text(String(format: "$%.2f", confirmed))
                            .foregroundColor(.secondary)
                    }
                    Text("Verify this matches what you paid, or edit the Cost field above.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Kroger Search

    private var krogerSearchView: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search for an ingredient…", text: $viewModel.searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Search") {
                    viewModel.searchProducts()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            if viewModel.isSearching {
                ProgressView("Searching Kroger…")
                    .padding()
                Spacer()
            } else if let error = viewModel.searchError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
                    .padding()
                Spacer()
            } else if viewModel.searchResults.isEmpty {
                Text("Search for an ingredient to see price suggestions from Kroger.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List(viewModel.searchResults) { product in
                    Button {
                        viewModel.selectProduct(product)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.description)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(product.displayPrice)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
