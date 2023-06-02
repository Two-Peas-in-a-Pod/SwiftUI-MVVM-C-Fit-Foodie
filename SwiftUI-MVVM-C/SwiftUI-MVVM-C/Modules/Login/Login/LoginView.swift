//
//  LoginView.swift
//  FitFoodie
//
//  Created by Justin Mooney on 6/1/23.
//


import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    // @ObservedObject var viewModel: LoginViewModel

    /*
     what is the difference between observedobject and stateobject?
     
        Both ObservedObject and StateObject are property wrappers in SwiftUI used to manage state and observe changes in objects that conform to the ObservableObject protocol. The primary difference between the two lies in how the lifecycle of the object is managed:

         @StateObject: This property wrapper is used when the view owns the data. When you declare an object as a StateObject, SwiftUI will ensure that this object gets created only once for each instance of the struct that declares it, and it won't be destroyed until the view is completely removed from the view hierarchy. This is very useful for data that needs to be maintained during the entire lifecycle of the view, such as a ViewModel in the MVVM pattern.
         @ObservedObject: This property wrapper is used when the view does not own the data, i.e., the data is passed into the view. The parent view or some external component owns the object, and the ObservedObject just subscribes to the updates. The lifecycle of an ObservedObject is not managed by SwiftUI. If the view that declares the ObservedObject is discarded by SwiftUI during a view update, the object can also be deallocated, causing a new one to be created during the next view update.

     */
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Login")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                
                VStack {
                    TextField("Username", text: $viewModel.username)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 25.0)
                                        .strokeBorder(Color.gray, lineWidth: 0.5))
                    
                    SecureField("Password", text: $viewModel.password)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 25.0)
                                        .strokeBorder(Color.gray, lineWidth: 0.5))
                }
                .padding(.horizontal)
                
                Button(action: {
                    viewModel.login()
                }) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(25.0)
                }
                .padding(.horizontal)
            }
            .padding(.top, 100)
        }
    }
}
