//
//  LoginCoordinator.swift
//  FitFoodie
//
//  Created by Justin Mooney on 6/1/23.
//

import SwiftUI

struct LoginCoordinator: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL
    
    let username: String
    
    var body: some View {
        NavigationView {
            LoginView()
            .navigationBarItems(leading: Button("Close", action: {
                presentationMode.wrappedValue.dismiss()
            }))
        }
    }
}
