//
// Copyright © 2022 Schibsted.
// Licensed under the terms of the MIT license. See LICENSE in the project root.
//

import Foundation

/// AuthenticatedURLSession wraps a User to allow Bearer authenticated requests and the use of URLSessionDataTask
public final class AuthenticatedURLSession {
    private let user: User
    private let urlSession: URLSession
    private var refreshTokenDataTask: URLSessionDataTask?

    /**
     Initializes a AuthenticatedURLSession for given user and session configuration

     - parameter user: The User object of whom tokens are used to authenticate requests.
     - parameter configuration: The URLSessionConfiguration object used for creating URLSession.
     
     */
    public init(user: User, configuration: URLSessionConfiguration) {
        self.user = user
        self.urlSession = URLSession(configuration: configuration)
    }

    /**
     Creates a task that retrieves the contents of a URL based on the specified URL request object. The request will be authenticated and the request will refresh on 401 failure.

     - parameter request: A URL request object that will be authenticated.
     
     */
    public func dataTask(with request: URLRequest) -> URLSessionDataTask {
        return dataTask(with: request) { _, _, _ in }
    }

    /**
     Creates a task that retrieves the contents of a URL based on the specified URL request object, and calls a handler upon completion. The request will be authenticated and the request will refresh on 401 failure.

     - parameter request: A URL request object that will be authenticated.
     - parameter completionHandler: The completion handler to call when the load request is complete.
     - returns Configured URLSessionDataTask.
     */
    public func dataTask(with request: URLRequest,
                         completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let user = self.user
        let request = authenticatedRequest(request, tokens: user.tokens)
        return urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.isError else {
                completionHandler(data, response, error)
                return
            }

            // 401 might indicate expired access token
            guard httpResponse.statusCode == 401 else {
                completionHandler(data, response, error)
                return
            }

            user.refreshTokens(clientId: user.client.configuration.clientId) { result in
                switch result {
                case .success(let tokens):
                    let requestWithRefreshedTokens = authenticatedRequest(request, tokens: tokens)
                    self?.refreshTokenDataTask = self?.urlSession.dataTask(
                        with: requestWithRefreshedTokens,
                        completionHandler: completionHandler
                    )
                    self?.refreshTokenDataTask?.resume()
                case .failure:
                    completionHandler(data, response, error)
                }
            }
        }
    }
}

private func authenticatedRequest(_ request: URLRequest, tokens: UserTokens?) -> URLRequest {
    var requestCopy = request
    if let bearer = tokens?.accessToken {
        requestCopy.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    }
    return requestCopy
}
