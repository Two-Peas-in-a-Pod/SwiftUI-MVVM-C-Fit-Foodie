//
//  ContentView.swift
//  SwiftUI-MVVM-C
//
//  Created by Nguyen Cong Huy on 5/17/21.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }
            MealPlanView()
                .tabItem {
                    Label("Meal Plan", systemImage: "calendar")
                }
        }
        .modelContainer(RecipeStore.shared)
    }
}
