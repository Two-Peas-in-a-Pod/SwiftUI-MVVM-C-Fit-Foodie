//
//  GroceryRouter.swift
//  SwiftUI-MVVM-C
//
//  Routes for the Kroger Developer API.
//  Register a free client at https://developer.kroger.com to obtain
//  a clientId and clientSecret, then set them in GroceryNetworkClient.
//

import Foundation
import Alamofire

enum GroceryRouter: RequestInfoConvertible {
    /// OAuth2 client-credentials token request
    case token(clientId: String, clientSecret: String)
    /// Product search by keyword
    case searchProducts(query: String, accessToken: String)

    private var baseURL: String { "https://api.kroger.com" }

    var urlString: String {
        switch self {
        case .token:
            return "\(baseURL)/v1/connect/oauth2/token"
        case .searchProducts:
            return "\(baseURL)/v1/products"
        }
    }

    func asRequestInfo() -> RequestInfo {
        switch self {
        case .token(let clientId, let clientSecret):
            let credentials = "\(clientId):\(clientSecret)"
            let encoded = Data(credentials.utf8).base64EncodedString()
            return RequestInfo(
                url: urlString,
                method: .post,
                parameters: ["grant_type": "client_credentials", "scope": "product.compact"],
                encoding: URLEncoding.httpBody,
                headers: HTTPHeaders([
                    "Authorization": "Basic \(encoded)",
                    "Content-Type": "application/x-www-form-urlencoded"
                ])
            )

        case .searchProducts(let query, let accessToken):
            return RequestInfo(
                url: urlString,
                method: .get,
                parameters: [
                    "filter.term": query,
                    "filter.limit": "10"
                ],
                encoding: URLEncoding.queryString,
                headers: HTTPHeaders([
                    "Authorization": "Bearer \(accessToken)",
                    "Accept": "application/json"
                ])
            )
        }
    }
}
