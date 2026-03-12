//
//  RecipeCell.swift  (RecipeCost module)
//  SwiftUI-MVVM-C
//

import SwiftUI

struct RecipeListCell: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name)
                .font(.headline)
            HStack {
                Text("\(recipe.servingsPerBatch) serving\(recipe.servingsPerBatch == 1 ? "" : "s") per batch")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(recipe.costResult().formattedTotalCost + " total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
