//
//  GroceryNetworkProvider.swift
//  SwiftUI-MVVM-C
//

import Foundation
import Combine

// MARK: - Response models

struct KrogerTokenResponse: Codable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct KrogerProductsResponse: Codable {
    let data: [KrogerProduct]
}

struct KrogerProduct: Codable, Identifiable {
    let productId: String
    let description: String
    let items: [KrogerItem]?

    var id: String { productId }

    /// Best price from the first item with a price, or nil if unavailable.
    var price: Double? {
        items?.compactMap { $0.price?.regular }.first
    }

    var displayPrice: String {
        guard let p = price else { return "Price unavailable" }
        return String(format: "$%.2f", p)
    }
}

struct KrogerItem: Codable {
    let price: KrogerPrice?
    let size: String?
}

struct KrogerPrice: Codable {
    let regular: Double?
    let promo: Double?
}

// MARK: - Protocol

protocol GroceryNetworkProvider {
    func searchProducts(query: String) -> AnyPublisher<[KrogerProduct], Error>
}

// MARK: - Implementation

class GroceryNetworkClient: GroceryNetworkProvider {
    var networkClient: NetworkProvider = NetworkClient.instance

    // Replace these with your credentials from https://developer.kroger.com
    private let clientId: String
    private let clientSecret: String

    private var cachedToken: String?
    private var cancellables = Set<AnyCancellable>()

    init(clientId: String = "", clientSecret: String = "") {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    func searchProducts(query: String) -> AnyPublisher<[KrogerProduct], Error> {
        fetchToken()
            .flatMap { [weak self] token -> AnyPublisher<[KrogerProduct], Error> in
                guard let self else {
                    return Fail(error: URLError(.cancelled)).eraseToAnyPublisher()
                }
                let publisher: AnyPublisher<KrogerProductsResponse, Error> =
                    self.networkClient
                        .request(GroceryRouter.searchProducts(query: query, accessToken: token))
                        .decode()
                return publisher.map { $0.data }.eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func fetchToken() -> AnyPublisher<String, Error> {
        if let token = cachedToken {
            return Just(token).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        let publisher: AnyPublisher<KrogerTokenResponse, Error> =
            networkClient
                .request(GroceryRouter.token(clientId: clientId, clientSecret: clientSecret))
                .decode()
        return publisher
            .map { [weak self] response -> String in
                self?.cachedToken = response.accessToken
                return response.accessToken
            }
            .eraseToAnyPublisher()
    }
}
