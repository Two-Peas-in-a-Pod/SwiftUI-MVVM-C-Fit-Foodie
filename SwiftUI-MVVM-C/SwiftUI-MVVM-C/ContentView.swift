//
//  ContentView.swift
//  SwiftUI-MVVM-C
//
//  Created by Nguyen Cong Huy on 5/17/21.
//

import SwiftUI

struct ContentView: View {
    static let username = "juicebyjustin"
    
    var body: some View {
        NavigationView {
            RepoListCoordinator(username: Self.username)   
        }
    }
}
