//
// Copyright © 2022 Schibsted.
// Licensed under the terms of the MIT license. See LICENSE in the project root.
//

import Foundation
import UIKit

enum RequestBuilder {
    case codeExchange(clientId: String)
    case oldSDKRefreshToken(oldSDKRefreshToken: String)
    case userContextFromToken
    case assertionForSimplifiedLogin

    func asRequest(baseURL: URL) -> URLRequest {
        switch self {
        case .codeExchange(clientId: let clientId):
            return exchangeRequest(baseURL: baseURL, clientId: clientId)
        case .oldSDKRefreshToken(oldSDKRefreshToken: let refreshToken):
            return buildOldSDKRefreshTokenRequest(baseURL: baseURL, oldSDKRefreshToken: refreshToken)
        case .userContextFromToken:
            return buildUserContextFromTokenRequest(baseURL: baseURL)
        case .assertionForSimplifiedLogin:
            return buildAssertionForSimplifiedLoginRequest(baseURL: baseURL)
        }
    }

    func exchangeRequest(baseURL: URL, clientId: String) -> URLRequest {
        let url = baseURL.appendingPathComponent("/api/2/oauth/exchange")
        let parameters = [
            "type": "code",
            "clientId": clientId
        ]
        guard let requestBody = HTTPUtil.formURLEncode(parameters: parameters) else {
            preconditionFailure("Failed to create code exchange request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(HTTPUtil.xWWWFormURLEncodedContentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        return request
    }

    func buildOldSDKRefreshTokenRequest(baseURL: URL, oldSDKRefreshToken: String) -> URLRequest {
        let url = baseURL.appendingPathComponent("/oauth/token")
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": oldSDKRefreshToken
        ]
        guard let requestBody = HTTPUtil.formURLEncode(parameters: parameters) else {
            preconditionFailure("Failed to create token request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(HTTPUtil.xWWWFormURLEncodedContentType, forHTTPHeaderField: "Content-Type")
        request.setValue("v1", forHTTPHeaderField: "X-OIDC")
        request.httpBody = requestBody
        return request
    }

    func buildUserContextFromTokenRequest(baseURL: URL) -> URLRequest {
        let url = baseURL.appendingPathComponent("/user-context-from-token")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(HTTPUtil.xWWWFormURLEncodedContentType, forHTTPHeaderField: "Content-Type")
        return request
    }

    func buildAssertionForSimplifiedLoginRequest(baseURL: URL) -> URLRequest {
        let url = baseURL.appendingPathComponent("/api/2/user/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(HTTPUtil.xWWWFormURLEncodedContentType, forHTTPHeaderField: "Content-Type")
        return request
    }
}

class SchibstedAccountAPI {

    private enum UserAgent {
        private static let deviceInfo = UIDevice.current
        static let value = "AccountSDKIOSWeb/\(sdkVersion) (\(deviceInfo.model); \(deviceInfo.systemName) \(deviceInfo.systemVersion))"
    }

    private let baseURL: URL
    private let sessionServiceURL: URL
    private let retryPolicy = APIRetryPolicy()

    init(baseURL: URL, sessionServiceURL: URL) {
        self.baseURL = baseURL
        self.sessionServiceURL = sessionServiceURL
    }

    static func addingSDKHeaders(to request: URLRequest) -> URLRequest {
        var requestWithHeaders = request
        requestWithHeaders.addValue(UserAgent.value, forHTTPHeaderField: "User-Agent")
        return requestWithHeaders
    }

    func sessionExchange(for user: User,
                         clientId: String,
                         redirectURI: String,
                         state: String? = nil,
                         completion: @escaping HTTPResultHandler<SessionExchangeResponse>) {
        let url = baseURL.appendingPathComponent("/api/2/oauth/exchange")
        var parameters = [
            "type": "session",
            "clientId": clientId,
            "redirectUri": redirectURI
        ]
        if let state = state {
            parameters["state"] = state
        }

        guard let requestBody = HTTPUtil.formURLEncode(parameters: parameters) else {
            preconditionFailure("Failed to create session exchange request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(HTTPUtil.xWWWFormURLEncodedContentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody

        user.withAuthentication(request: SchibstedAccountAPI.addingSDKHeaders(to: request), clientId: clientId) {
            completion(self.unpackResponse($0))
        }
    }

    func codeExchange(for user: User, clientId: String, completion: @escaping HTTPResultHandler<CodeExchangeResponse>) {
        let request = RequestBuilder.codeExchange(clientId: clientId).asRequest(baseURL: baseURL)

        user.withAuthentication(request: SchibstedAccountAPI.addingSDKHeaders(to: request), clientId: clientId) {
            completion(self.unpackResponse($0))
        }
    }

    func userContextFromToken(for user: User, clientId: String, completion: @escaping HTTPResultHandler<UserContextFromTokenResponse>) {
        let request = RequestBuilder.userContextFromToken.asRequest(baseURL: sessionServiceURL)

        user.withAuthentication(request: SchibstedAccountAPI.addingSDKHeaders(to: request), clientId: clientId) {
            completion($0)
        }
    }

    func assertionForSimplifiedLogin(for user: User, clientId: String, completion: @escaping HTTPResultHandler<SimplifiedLoginAssertionResponse>) {
        let request = RequestBuilder.assertionForSimplifiedLogin.asRequest(baseURL: baseURL)

        user.withAuthentication(request: SchibstedAccountAPI.addingSDKHeaders(to: request), clientId: clientId) {
            completion(self.unpackResponse($0))
        }
    }

    func tokenRequest(with httpClient: HTTPClient,
                      parameters: [String: String],
                      completion: @escaping HTTPResultHandler<TokenResponse>) {
        let url = baseURL.appendingPathComponent("/oauth/token")
        guard let requestBody = HTTPUtil.formURLEncode(parameters: parameters) else {
            preconditionFailure("Failed to create token request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(HTTPUtil.xWWWFormURLEncodedContentType, forHTTPHeaderField: "Content-Type")
        request.setValue("v1", forHTTPHeaderField: "X-OIDC")
        request.httpBody = requestBody

        httpClient.execute(request: SchibstedAccountAPI.addingSDKHeaders(to: request),
                           withRetryPolicy: retryPolicy,
                           completion: completion)
    }

    func userProfile(for user: User, clientId: String, completion: @escaping HTTPResultHandler<UserProfileResponse>) {
        guard let userUuid = user.uuid else {
            completion(.failure(.unexpectedError(underlying: LoginStateError.notLoggedIn)))
            return
        }
        let url = baseURL.appendingPathComponent("/api/2/user/\(userUuid)")
        let request = URLRequest(url: url)
        user.withAuthentication(
            request: SchibstedAccountAPI.addingSDKHeaders(to: request),
            clientId: clientId
        ) {
            completion(self.unpackResponse($0))
        }
    }

    private func unpackResponse<T>(_ response: Result<SchibstedAccountAPIResponse<T>, HTTPError>) -> Result<T, HTTPError> {
        switch response {
        case .success(let result):
            return .success(result.data)
        case .failure(let error):
            return .failure(error)
        }
    }
}
