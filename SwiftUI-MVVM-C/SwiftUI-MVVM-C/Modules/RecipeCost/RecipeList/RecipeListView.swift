//
//  RecipeListView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData
import EventKit
import UIKit

struct RecipeListView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingRecipe = false
    @State private var isShowingSettings = false
    @State private var searchText = ""

    private var filteredRecipes: [Recipe] {
        searchText.isEmpty ? recipes : recipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeListCell(recipe: recipe)
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
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
                } else if filteredRecipes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        offsets.map { filteredRecipes[$0] }.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Add Recipe Sheet

private struct AddRecipeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum InputMode: String, CaseIterable {
        case manual = "Manual"
        case paste  = "Paste"
    }

    @State private var inputMode: InputMode = .manual
    @State private var name = ""
    @State private var servingsText = "1"
    @State private var pastedText = ""
    @State private var parseWarning: String? = nil
    @State private var partialParseResult: ParsedRecipe? = nil

    private var nameIsEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var addDisabled: Bool {
        nameIsEmpty || (inputMode == .paste && pastedText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Input mode", selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if inputMode == .manual {
                    Form {
                        Section(header: Text("Recipe Name")) {
                            TextField("e.g. Chocolate Chip Cookies", text: $name)
                        }
                        Section(header: Text("Servings per Batch")) {
                            TextField("e.g. 24", text: $servingsText)
                                .keyboardType(.numberPad)
                        }
                    }
                } else {
                    pasteForm
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button(inputMode == .manual ? "Add" : "Import") {
                    inputMode == .manual ? saveManual() : savePaste()
                }
                .disabled(addDisabled)
            )
            .alert("Some Ingredients Couldn't Be Parsed", isPresented: .init(
                get: { partialParseResult != nil },
                set: { if !$0 { partialParseResult = nil } }
            )) {
                Button("Import \(partialParseResult?.ingredients.count ?? 0) Ingredient\(partialParseResult?.ingredients.count == 1 ? "" : "s")") {
                    if let p = partialParseResult { commitPaste(p) }
                }
                Button("Cancel", role: .cancel) { partialParseResult = nil }
            } message: {
                if let p = partialParseResult {
                    Text("\(p.skippedCount) ingredient\(p.skippedCount == 1 ? "" : "s") couldn't be parsed and will be skipped. Check those lines for format errors, or import what was found.")
                }
            }
        }
    }

    // MARK: - Paste form

    private var pasteForm: some View {
        Form {
            Section(header: Text("Recipe Name")) {
                TextField("e.g. Chocolate Chip Cookies", text: $name)
            }
            Section(header: Text("Servings per Batch")) {
                TextField("e.g. 24", text: $servingsText)
                    .keyboardType(.numberPad)
            }
            Section(
                header: Text("Ingredients"),
                footer: formatHint
            ) {
                TextEditor(text: $pastedText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .onChange(of: pastedText) { _, _ in parseWarning = nil; partialParseResult = nil }
            }
            if let warning = parseWarning {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private var formatHint: some View {
        Text("One ingredient per pair of lines:\nSpinach, $2.35/bag\nUse: 1/2 cup\n\nFractions (1/2, 3/4) and decimals (0.5) are both supported.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    // MARK: - Save

    private func saveManual() {
        let servings = max(1, Int(servingsText) ?? 1)
        let recipe = Recipe(name: name.trimmingCharacters(in: .whitespaces), servingsPerBatch: servings)
        modelContext.insert(recipe)
        try? modelContext.save()
        dismiss()
    }

    private func savePaste() {
        let parsed = RecipeTextParser.parse(pastedText)
        guard !parsed.ingredients.isEmpty else {
            parseWarning = "No ingredients could be read — check the format above."
            return
        }
        if parsed.skippedCount > 0 {
            partialParseResult = parsed
            return
        }
        commitPaste(parsed)
    }

    private func commitPaste(_ parsed: ParsedRecipe) {
        let servings = max(1, Int(servingsText) ?? 1)
        let recipe = Recipe(name: name.trimmingCharacters(in: .whitespaces), servingsPerBatch: servings)
        modelContext.insert(recipe)
        for pi in parsed.ingredients {
            let ingredient = Ingredient(
                name: pi.name,
                purchaseCost: pi.purchaseCost,
                purchaseQuantity: pi.purchaseQuantity,
                purchaseUnit: pi.purchaseUnit,
                recipeQuantity: pi.recipeQuantity,
                recipeUnit: pi.recipeUnit,
                isAlcohol: AddIngredientViewModel.detectsAlcohol(in: pi.name)
            )
            recipe.ingredients.append(ingredient)
            modelContext.insert(ingredient)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Cost Settings

struct CostSettingsSheet: View {
    @AppStorage("salesTaxRate") private var salesTaxRate: Double = 0
    @AppStorage("alcoholTaxRate") private var alcoholTaxRate: Double = 0
    @AppStorage("krogerClientId") private var krogerClientId: String = ""
    @AppStorage("krogerClientSecret") private var krogerClientSecret: String = ""
    @AppStorage("costGoalEnabled") private var costGoalEnabled: Bool = false
    @AppStorage("weeklyBudgetEnabled") private var weeklyBudgetEnabled: Bool = false
    @AppStorage("preferredCalendarId") private var preferredCalendarId: String = ""
    @AppStorage("weekStartsOnSunday") private var weekStartsOnSunday: Bool = true
    @Environment(\.dismiss) private var dismiss

    @StateObject private var calendarService = MealPlanCalendarService.shared
    @State private var isShowingCalendarPicker = false

    @State private var groceryTaxText = ""
    @State private var alcoholTaxText = ""
    @State private var clientIdText = ""
    @State private var clientSecretText = ""

    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Grocery Tax Rate"),
                    footer: Text("Tax rate applied to regular grocery ingredients. Leave at 0 if groceries aren't taxed in your area.")
                ) {
                    HStack {
                        TextField("e.g. 8.5", text: $groceryTaxText)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }

                Section(
                    header: Text("Alcohol Tax Rate"),
                    footer: Text("Tax rate applied to ingredients marked as Alcohol. Often higher than the grocery rate.")
                ) {
                    HStack {
                        TextField("e.g. 10.25", text: $alcoholTaxText)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }

                Section(
                    header: Text("Recipe Features"),
                    footer: Text("When enabled, you can set a target cost per serving on each recipe and see a color indicator showing how close you are to your goal.")
                ) {
                    Toggle("Cost Goal per Serving", isOn: $costGoalEnabled)
                }

                Section(
                    header: Text("Meal Plan"),
                    footer: Text("Track your weekly meal spending against a budget.")
                ) {
                    Picker("Week Starts On", selection: $weekStartsOnSunday) {
                        Text("Sunday").tag(true)
                        Text("Monday").tag(false)
                    }
                    Toggle("Weekly Budget", isOn: $weeklyBudgetEnabled)
                    HStack {
                        Text("Calendar")
                        Spacer()
                        let calName = calendarService.calendar(for: preferredCalendarId)?.title
                        Button(calName ?? "None") {
                            Task {
                                if !calendarService.isAuthorized {
                                    _ = await calendarService.requestAccess()
                                }
                                isShowingCalendarPicker = true
                            }
                        }
                        .foregroundColor(calName == nil ? .accentColor : .secondary)
                    }
                }

                Section(
                    header: Text("Kroger API"),
                    footer: Text("Credentials from developer.kroger.com. Required to use the ingredient price lookup feature. Stored locally on your device.")
                ) {
                    TextField("Client ID", text: $clientIdText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("Client Secret", text: $clientSecretText)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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
            .sheet(isPresented: $isShowingCalendarPicker) {
                CalendarPickerSheet(preferredCalendarId: preferredCalendarId) { cal in
                    preferredCalendarId = cal.calendarIdentifier
                }
            }
            .onAppear {
                groceryTaxText = salesTaxRate == 0 ? "" : String(format: "%g", salesTaxRate)
                alcoholTaxText = alcoholTaxRate == 0 ? "" : String(format: "%g", alcoholTaxRate)
                clientIdText = krogerClientId
                clientSecretText = krogerClientSecret
            }
        }
    }

    private func save() {
        salesTaxRate = Double(groceryTaxText) ?? 0
        alcoholTaxRate = Double(alcoholTaxText) ?? 0
        krogerClientId = clientIdText.trimmingCharacters(in: .whitespaces)
        krogerClientSecret = clientSecretText
        dismiss()
    }
}
