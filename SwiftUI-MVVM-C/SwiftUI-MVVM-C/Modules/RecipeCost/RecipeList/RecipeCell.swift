//
//  RecipeCell.swift  (RecipeCost module)
//  SwiftUI-MVVM-C
//

import SwiftUI

struct RecipeListCell: View {
    let recipe: Recipe
    @AppStorage("salesTaxRate") private var salesTaxRate: Double = 0
    @AppStorage("alcoholTaxRate") private var alcoholTaxRate: Double = 0

    private var costResult: RecipeCostResult {
        recipe.costResult(groceryTaxRate: salesTaxRate, alcoholTaxRate: alcoholTaxRate)
    }

    /// nil when no goal is set; otherwise green / orange / red
    private var budgetIndicatorColor: Color? {
        let target = recipe.targetCostPerServing
        guard target > 0 else { return nil }
        let actual = costResult.costPerServingWithTax
        if actual <= target { return .green }
        if actual <= target * 1.25 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(recipe.name)
                    .font(.headline)
                if let color = budgetIndicatorColor {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
            }
            HStack {
                Text("\(recipe.servingsPerBatch) serving\(recipe.servingsPerBatch == 1 ? "" : "s") per batch")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(costResult.formattedTotalCost + " total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
