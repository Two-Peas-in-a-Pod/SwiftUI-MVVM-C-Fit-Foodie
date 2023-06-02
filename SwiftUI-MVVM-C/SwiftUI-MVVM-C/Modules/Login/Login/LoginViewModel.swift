//
//  LoginViewModel.swift
//  FitFoodie
//
//  Created by Justin Mooney on 6/1/23.
//

import Foundation
import Combine

class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""

   // var coordinator: LoginCoordinator

    init(/*coordinator: LoginCoordinator*/) {
       // self.coordinator = coordinator
    }

    func login() {
       // coordinator.login(username: username, password: password)
    }
}
