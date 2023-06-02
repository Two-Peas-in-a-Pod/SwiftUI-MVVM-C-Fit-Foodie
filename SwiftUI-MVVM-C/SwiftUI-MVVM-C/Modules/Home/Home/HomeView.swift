//
//  HomeView.swift
//  FitFoodie-AI
//
//  Created by Justin Mooney on 6/1/23.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    let username: String
    let tapOnLinkAction: (URL) -> Void
    
    var user: User? {
        viewModel.user
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text(viewModel.username ?? "")
                .font(.title)
                .leadingAlignment()
            
            Text(viewModel.displayName ?? "")
                .font(.title2)
                .leadingAlignment()
            
            Text(viewModel.bio ?? "")
            
            VStack {
                Text(viewModel.publicReposText ?? "")
                    .leadingAlignment()
                Text(viewModel.publicGistsText ?? "")
                    .leadingAlignment()
                Text(viewModel.followersText ?? "")
                    .leadingAlignment()
                Text(viewModel.followingText ?? "")
                    .leadingAlignment()
            }
            
            Button("Open Github website to see more details") {
                if let url = user?.htmlURL {
                    tapOnLinkAction(url)
                }
            }
            .leadingAlignment()
            
            Spacer()
        }
        .padding()
        .onAppear(perform: {
            viewModel.getUser(username: username)
        })
        .navigationBarTitle("Home", displayMode: .inline)
    }
}
