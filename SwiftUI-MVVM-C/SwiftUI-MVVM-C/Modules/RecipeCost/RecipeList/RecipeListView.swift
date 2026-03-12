//
//  RecipeListView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData

struct RecipeListView: View {
    @StateObject private var viewModel = RecipeListViewModel()
    @Environment(\.modelContext) private var modelContext
    let tapOnRecipeAction: (Recipe) -> Void

    var body: some View {
        List {
            ForEach(viewModel.recipes) { recipe in
                Button {
                    tapOnRecipeAction(recipe)
                } label: {
                    RecipeListCell(recipe: recipe)
                }
            }
            .onDelete { offsets in
                viewModel.deleteRecipes(at: offsets, from: modelContext)
            }
        }
        .onAppear {
            viewModel.loadRecipes(from: modelContext)
        }
        .sheet(isPresented: $viewModel.isAddingRecipe) {
            addRecipeSheet
        }
        .navigationBarTitle("Recipes", displayMode: .inline)
        .navigationBarItems(trailing:
            Button {
                viewModel.isAddingRecipe = true
            } label: {
                Image(systemName: "plus")
            }
        )
    }

    private var addRecipeSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipe Name")) {
                    TextField("e.g. Chocolate Chip Cookies", text: $viewModel.newRecipeName)
                }
                Section(header: Text("Servings per Batch")) {
                    TextField("e.g. 24", text: $viewModel.newRecipeServings)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarItems(
                leading: Button("Cancel") {
                    viewModel.isAddingRecipe = false
                },
                trailing: Button("Add") {
                    viewModel.addRecipe(to: modelContext)
                }
                .disabled(viewModel.newRecipeName.trimmingCharacters(in: .whitespaces).isEmpty)
            )
        }
    }
}
