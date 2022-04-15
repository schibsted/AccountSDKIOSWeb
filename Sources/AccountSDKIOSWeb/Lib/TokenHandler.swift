import Foundation
import JOSESwift

internal enum TokenError: Error {
    case tokenRequestError(HTTPError)
    case idTokenError(IdTokenValidationError)
}

internal struct TokenResult: CustomStringConvertible {
    let userTokens: UserTokens
    let scope: String?
    let expiresIn: Int

    var description: String {
        return "TokenResult("
            + "userTokens: \(userTokens),\n"
            + "scope: \(scope ?? ""),\n"
            + "expiresIn: \(expiresIn))"

    }
}

internal struct TokenResponse: Codable, Equatable, CustomStringConvertible {
    // swiftlint:disable identifier_name
    let access_token: String
    let refresh_token: String?
    let id_token: String?
    let scope: String?
    let expires_in: Int

    var description: String {
        return "TokenResponse("
            + "access_token: \(removeSignature(fromToken: access_token)),\n"
            + "refresh_token: \(removeSignature(fromToken: refresh_token)),\n"
            + "id_token: \(removeSignature(fromToken: id_token)),\n"
            + "scope: \(scope ?? ""),\n"
            + "expires_in: \(expires_in))"

    }
}

func removeSignature(fromToken token: String?) -> String {
    guard let value = token else {
        return ""
    }

    let split = value.components(separatedBy: ".")

    if split.count < 2 {
        let tokenPrefix = token?.prefix(3) ?? ""
        return "\(tokenPrefix)..."
    }

    return "\(split[0]).\(split[1])"
}

internal class TokenHandler {
    private let configuration: ClientConfiguration
    private let httpClient: HTTPClient
    private let schibstedAccountAPI: SchibstedAccountAPI
    let jwks: JWKS

    init(configuration: ClientConfiguration, httpClient: HTTPClient, jwks: JWKS) {
        self.configuration = configuration
        self.httpClient = httpClient
        self.schibstedAccountAPI = SchibstedAccountAPI(baseURL: configuration.serverURL,
                                                       sessionServiceURL: configuration.sessionServiceURL)
        self.jwks = jwks
    }

    func makeTokenRequest(authCode: String,
                          authState: AuthState?,
                          completion: @escaping (Result<TokenResult, TokenError>) -> Void) {
        var parameters = [
            "client_id": configuration.clientId,
            "grant_type": "authorization_code",
            "code": authCode,
            "redirect_uri": configuration.redirectURI.absoluteString
        ]
        if let codeVerifier = authState?.codeVerifier { parameters["code_verifier"] = codeVerifier }

        schibstedAccountAPI.tokenRequest(with: httpClient, parameters: parameters) { result in
            switch result {
            case .success(let tokenResponse):
                guard let idToken = tokenResponse.id_token else {
                    completion(.failure(.idTokenError(.missingIdToken)))
                    return
                }

                let idTokenValidationContext = IdTokenValidationContext(issuer: self.configuration.issuer,
                                                                        clientId: self.configuration.clientId,
                                                                        nonce: authState?.nonce,
                                                                        expectedAMR: authState?.mfa?.rawValue)

                IdTokenValidator.validate(idToken: idToken,
                                          jwks: self.jwks,
                                          context: idTokenValidationContext) { result in
                    switch result {
                    case .success(let claims):
                        let userTokens = UserTokens(accessToken: tokenResponse.access_token,
                                                    refreshToken: tokenResponse.refresh_token,
                                                    idToken: idToken,
                                                    idTokenClaims: claims)
                        let tokenResult = TokenResult(userTokens: userTokens,
                                                      scope: tokenResponse.scope,
                                                      expiresIn: tokenResponse.expires_in)
                        completion(.success(tokenResult))
                        return
                    case .failure(let idTokenValidationError):
                        completion(.failure(.idTokenError(idTokenValidationError)))
                    }
                }
            case .failure(let httpError):
                completion(.failure(.tokenRequestError(httpError)))
                return
            }

        }
    }

    func makeTokenRequest(refreshToken: String,
                          scope: String? = nil,
                          completion: @escaping HTTPResultHandler<TokenResponse>) {
        var parameters = [
            "client_id": configuration.clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        scope.map { parameters["scope"] = $0 }

        schibstedAccountAPI.tokenRequest(with: httpClient, parameters: parameters, completion: completion)
    }
}
