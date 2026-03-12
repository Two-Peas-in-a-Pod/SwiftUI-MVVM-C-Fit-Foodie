//
//  ContentView.swift
//  SwiftUI-MVVM-C
//
//  Created by Nguyen Cong Huy on 5/17/21.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    static let username = "juicebyjustin"

    var body: some View {
        TabView {
            NavigationView {
                RecipeCostCoordinator()
            }
            .tabItem {
                Label("Recipes", systemImage: "fork.knife")
            }

            NavigationView {
                RepoListCoordinator(username: Self.username)
            }
            .tabItem {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
        .modelContainer(RecipeStore.shared)
    }
}
