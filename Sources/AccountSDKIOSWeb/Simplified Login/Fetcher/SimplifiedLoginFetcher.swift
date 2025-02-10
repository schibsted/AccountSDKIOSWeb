//
// Copyright © 2022 Schibsted.
// Licensed under the terms of the MIT license. See LICENSE in the project root.
//

import Foundation

typealias SimplifiedLoginFetchedData = (context: UserContextFromTokenResponse, profile: UserProfileResponse)
typealias SimplifiedLoginAssertionResult = Result<SimplifiedLoginAssertionResponse, Error>

protocol SimplifiedLoginFetching {
    func fetchData(completion: @escaping (Result<SimplifiedLoginFetchedData, Error>) -> Void)
    func fetchAssertion(clientId: String, completion: @escaping (Result<SimplifiedLoginAssertionResponse, Error>) -> Void)
}

class SimplifiedLoginFetcher: SimplifiedLoginFetching {
    let client: Client
    init(client: Client) {
        self.client = client
    }

    var retainedSharedUser: User?
    func getLatestSharedUserSession() throws -> UserSession {
        guard let latestUserSession = client.getLatestSharedSession() else {
            throw SimplifiedLoginManager.SimplifiedLoginError.noLoggedInSessionInSharedKeychain
        }
        return latestUserSession
    }

    func fetchData(completion: @escaping (Result<SimplifiedLoginFetchedData, Error>) -> Void) {
        do {
            let latestUserSession = try getLatestSharedUserSession()
            let user = User(client: client, tokens: latestUserSession.userTokens)
            let clientId = latestUserSession.clientId
            self.retainedSharedUser = user
            user.userContextFromToken(clientId: clientId) { result in
                switch result {
                case .success(let userContextResponse):
                    self.fetchProfile(user: user, clientId: clientId, userContext: userContextResponse, completion: completion)
                case .failure(let error):
                    SchibstedAccountLogger.instance
                        .error("Failed to fetch userContextFromToken: \(String(describing: error))")
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func fetchProfile(user: User,
                      clientId: String,
                      userContext: UserContextFromTokenResponse,
                      completion: @escaping (Result<SimplifiedLoginFetchedData, Error>) -> Void) {
        user.fetchProfileData(clientId: clientId) { result in
            switch result {
            case .success(let profileResponse):
                completion(.success((userContext, profileResponse)))
            case .failure(let error):
                SchibstedAccountLogger.instance.error("Failed to fetch profileData: \(String(describing: error))")
                completion(.failure(error))
            }
        }
    }

    func fetchAssertion(clientId: String, completion: @escaping (SimplifiedLoginAssertionResult) -> Void) {
        guard let user = retainedSharedUser else {
            completion(.failure(SimplifiedLoginManager.SimplifiedLoginError.noLoggedInSessionInSharedKeychain))
            return
        }

        user.assertionForSimplifiedLogin(clientId: clientId) { result in
            switch result {
            case .success(let assertionResponse):
                completion(.success(assertionResponse))
            case .failure(let error):
                SchibstedAccountLogger.instance
                    .error("Failed to fetch Simplified Login assertion: \(String(describing: error))")
                completion(.failure(error))
            }
        }
    }
}
