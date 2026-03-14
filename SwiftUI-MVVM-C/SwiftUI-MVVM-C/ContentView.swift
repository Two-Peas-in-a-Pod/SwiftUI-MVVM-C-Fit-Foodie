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
        RecipeListView()
            .modelContainer(RecipeStore.shared)
    }
}
