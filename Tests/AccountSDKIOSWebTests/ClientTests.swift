import XCTest
import Cuckoo
@testable import AccountSDKIOSWeb

final class ClientTests: XCTestCase {
    private let config = ClientConfiguration(environment: .pre, clientId: "client1", clientSecret: "clientSecret", redirectURI: URL("com.example.client1://login"))

    private static let keyId = "test key"
    private static var jwsUtil: JWSUtil!
    
    override class func setUp() {
        jwsUtil = JWSUtil()
    }

    func testLoginURL() {
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            when(mock.setValue(any(), forKey: Client.webFlowLoginStateKey)).thenDoNothing()
        }

        let client = Client(configuration: config, sessionStorage: MockSessionStorage(), stateStorage: StateStorage(storage: mockStorage))
        let loginURL = client.loginURL()
        
        XCTAssertEqual(loginURL?.scheme, "https")
        XCTAssertEqual(loginURL?.host, "identity-pre.schibsted.com")
        XCTAssertEqual(loginURL?.path, "/oauth/authorize")
        
        let components = URLComponents(url: loginURL!, resolvingAgainstBaseURL: true)
        let queryParams = components?.queryItems?.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
        
        XCTAssertEqual(queryParams!["client_id"], config.clientId)
        XCTAssertEqual(queryParams!["redirect_uri"], config.redirectURI.absoluteString)
        XCTAssertEqual(queryParams!["response_type"], "code")
        XCTAssertEqual(queryParams!["prompt"], "select_account")
        XCTAssertEqual(queryParams!["scope"], "openid")
        XCTAssertNotNil(queryParams!["state"])
        XCTAssertNotNil(queryParams!["nonce"])
        XCTAssertNotNil(queryParams!["code_challenge"])
        XCTAssertEqual(queryParams!["code_challenge_method"], "S256")
    }
    
    func testLoginURLWithExtraScopes() {
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            when(mock.setValue(any(), forKey: Client.webFlowLoginStateKey)).thenDoNothing()
        }
        let client = Client(configuration: config, sessionStorage: MockSessionStorage(), stateStorage: StateStorage(storage: mockStorage))
        let loginURL = client.loginURL(extraScopeValues: ["scope1", "scope2"])
        
        XCTAssertEqual(loginURL?.scheme, "https")
        XCTAssertEqual(loginURL?.host, "identity-pre.schibsted.com")
        XCTAssertEqual(loginURL?.path, "/oauth/authorize")
        
        let components = URLComponents(url: loginURL!, resolvingAgainstBaseURL: true)
        let queryParams = components?.queryItems?.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }

        let scope = Set(queryParams!["scope"]!.components(separatedBy: " "))
        XCTAssertEqual(queryParams!["client_id"], config.clientId)
        XCTAssertEqual(queryParams!["redirect_uri"], config.redirectURI.absoluteString)
        XCTAssertEqual(queryParams!["response_type"], "code")
        XCTAssertEqual(queryParams!["prompt"], "select_account")
        XCTAssertEqual(scope, Set(["openid", "scope1", "scope2"]))
        XCTAssertNotNil(queryParams!["state"])
        XCTAssertNotNil(queryParams!["nonce"])
        XCTAssertNotNil(queryParams!["code_challenge"])
        XCTAssertEqual(queryParams!["code_challenge_method"], "S256")
    }
    
    func testLoginURLWithMFAIncludesACRValues() {
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            when(mock.setValue(any(), forKey: Client.webFlowLoginStateKey)).thenDoNothing()
        }
        let client = Client(configuration: config, sessionStorage: MockSessionStorage(), stateStorage: StateStorage(storage: mockStorage))
        let loginURL = client.loginURL(withMFA: .otp)
        
        XCTAssertEqual(loginURL?.scheme, "https")
        XCTAssertEqual(loginURL?.host, "identity-pre.schibsted.com")
        XCTAssertEqual(loginURL?.path, "/oauth/authorize")
        
        let components = URLComponents(url: loginURL!, resolvingAgainstBaseURL: true)
        let queryParams = components?.queryItems?.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }

        XCTAssertEqual(queryParams!["acr_values"], "otp")
        XCTAssertNil(queryParams!["prompt"])

        XCTAssertEqual(queryParams!["client_id"], config.clientId)
        XCTAssertEqual(queryParams!["redirect_uri"], config.redirectURI.absoluteString)
        XCTAssertEqual(queryParams!["response_type"], "code")
        XCTAssertEqual(queryParams!["scope"], "openid")
        XCTAssertNotNil(queryParams!["state"])
        XCTAssertNotNil(queryParams!["nonce"])
        XCTAssertNotNil(queryParams!["code_challenge"])
        XCTAssertEqual(queryParams!["code_challenge_method"], "S256")
    }

    func testHandleAuthenticationResponseRejectsUnsolicitedResponse() {
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            when(mock.value(forKey: Client.webFlowLoginStateKey)).thenReturn(nil)
        }
        let client = Client(configuration: config, sessionStorage: MockSessionStorage(), stateStorage: StateStorage(storage: mockStorage))
        
        let callbackExpectation = expectation(description: "Returns error to callback closure")
        
        client.handleAuthenticationResponse(url: URL("com.example://login?state=no-exist&code=123456")) { result in
            XCTAssertEqual(result, .failure(.unsolicitedResponse))
            callbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }
    
    func testHandleAuthenticationResponseHandlesErrorResponse() {
        let state = "testState"
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            let webFlowData = WebFlowData(state: state, nonce: "testNonce", codeVerifier: "codeVerifier", mfa: nil)
            when(mock.value(forKey: Client.webFlowLoginStateKey)).thenReturn(try! JSONEncoder().encode(webFlowData))
            when(mock.removeValue(forKey: Client.webFlowLoginStateKey)).thenDoNothing()
        }
        
        let client = Client(configuration: config, sessionStorage: MockSessionStorage(), stateStorage: StateStorage(storage: mockStorage))
        let callbackExpectation = expectation(description: "Returns error to callback closure")
        client.handleAuthenticationResponse(url: URL(string: "com.example://login?state=\(state)&error=invalid_request&error_description=test%20error")!) { result in
            XCTAssertEqual(result, .failure(.authenticationErrorResponse(error: OAuthError(error: "invalid_request", errorDescription: "test error"))))
            callbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }
    
    func testHandleAuthenticationResponseHandlesMissingAuthCode() {
        let state = "testState"
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            let webFlowData = WebFlowData(state: state, nonce: "testNonce", codeVerifier: "codeVerifier", mfa: nil)
            when(mock.value(forKey: Client.webFlowLoginStateKey)).thenReturn(try! JSONEncoder().encode(webFlowData))
            when(mock.removeValue(forKey: Client.webFlowLoginStateKey)).thenDoNothing()
        }

        let client = Client(configuration: config, sessionStorage: MockSessionStorage(), stateStorage: StateStorage(storage: mockStorage))
        let callbackExpectation = expectation(description: "Returns error to callback closure")
        client.handleAuthenticationResponse(url: URL(string: "com.example://login?state=\(state)")!) { result in
            XCTAssertEqual(result, .failure(.unexpectedError(message: "Missing authorization code from authentication response")))
            callbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    func testHandleAuthenticationResponseHandlesSuccessResponse() {
        let idToken = createIdToken(claims: Fixtures.idTokenClaims)
        let tokenResponse = TokenResponse(access_token: "accessToken", refresh_token: "refreshToken", id_token: idToken, scope: "openid", expires_in: 3600)
        let mockHTTPClient = MockHTTPClient()
        
        stub(mockHTTPClient) { mock in
            when(mock.post(url: equal(to: config.serverURL.appendingPathComponent("/oauth/token")),
                           body: any(),
                           contentType: HTTPUtil.xWWWFormURLEncodedContentType,
                           authorization: HTTPUtil.basicAuth(username: config.clientId, password: config.clientSecret),
                           completion: anyClosure()))
                .then { _, _, _, _, completion in
                    completion(.success(tokenResponse))
                }
            
            let jwksResponse = JWKSResponse(keys: [RSAJWK(kid: ClientTests.keyId, kty: "RSA", e: ClientTests.jwsUtil.publicJWK.exponent, n: ClientTests.jwsUtil.publicJWK.modulus, alg: "RS256", use: "sig")])
            when(mock.get(url: equal(to: config.serverURL.appendingPathComponent("/oauth/jwks")), completion: anyClosure()))
                .then { _, completion in
                    completion(.success(jwksResponse))
                }
        }
        
        let mockSessionStorage = MockSessionStorage()
        stub(mockSessionStorage) { mock in
            when(mock.store(any())).thenDoNothing()
        }
        let state = "testState"
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            let webFlowData = WebFlowData(state: state, nonce: Fixtures.idTokenClaims.nonce!, codeVerifier: "codeVerifier", mfa: nil)
            when(mock.value(forKey: Client.webFlowLoginStateKey)).thenReturn(try! JSONEncoder().encode(webFlowData))
            when(mock.removeValue(forKey: Client.webFlowLoginStateKey)).thenDoNothing()
        }

        let client = Client(configuration: config, sessionStorage: mockSessionStorage, stateStorage: StateStorage(storage: mockStorage), httpClient: mockHTTPClient)
        let callbackExpectation = expectation(description: "Exchanges code for user tokens")
        client.handleAuthenticationResponse(url: URL(string: "com.example://login?code=12345&state=\(state)")!) { result in
            XCTAssertEqual(result, .success(User(sessionStorage: MockSessionStorage(),  clientId: self.config.clientId, accessToken: tokenResponse.access_token, refreshToken: tokenResponse.refresh_token, idToken: idToken, idTokenClaims: Fixtures.idTokenClaims)))
            callbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }
    
    func testHandleAuthenticationResponseRejectsExpectedAMRValueInIdToken() {
        let nonce = "testNonce"
        let idTokenClaims = IdTokenClaims(sub: "userUuid", nonce: nonce, amr: nil) // no AMR in ID Token
        let idToken = createIdToken(claims: idTokenClaims)
        let tokenResponse = TokenResponse(access_token: "accessToken", refresh_token: "refreshToken", id_token: idToken, scope: "openid", expires_in: 3600)
        let mockHTTPClient = MockHTTPClient()
        
        stub(mockHTTPClient) { mock in
            when(mock.post(url: equal(to: config.serverURL.appendingPathComponent("/oauth/token")),
                           body: any(),
                           contentType: HTTPUtil.xWWWFormURLEncodedContentType,
                           authorization: HTTPUtil.basicAuth(username: config.clientId, password: config.clientSecret),
                           completion: anyClosure()))
                .then { _, _, _, _, completion in
                    completion(.success(tokenResponse))
                }
            
            let jwksResponse = JWKSResponse(keys: [RSAJWK(kid: ClientTests.keyId, kty: "RSA", e: ClientTests.jwsUtil.publicJWK.exponent, n: ClientTests.jwsUtil.publicJWK.modulus, alg: "RS256", use: "sig")])
            when(mock.get(url: equal(to: config.serverURL.appendingPathComponent("/oauth/jwks")), completion: anyClosure()))
                .then { _, completion in
                    completion(.success(jwksResponse))
                }
        }

        let state = "testState"
        let mockStorage = MockStorage()
        stub(mockStorage) { mock in
            let webFlowData = WebFlowData(state: state, nonce: nonce, codeVerifier: "codeVerifier", mfa: MFAType.otp)
            when(mock.value(forKey: Client.webFlowLoginStateKey)).thenReturn(try! JSONEncoder().encode(webFlowData))
            when(mock.removeValue(forKey: Client.webFlowLoginStateKey)).thenDoNothing()
        }
        
        let client = Client(configuration: config, sessionStorage: MockSessionStorage(), stateStorage: StateStorage(storage: mockStorage), httpClient: mockHTTPClient)
        let callbackExpectation = expectation(description: "Exchanges code for user tokens")
        client.handleAuthenticationResponse(url: URL(string: "com.example://login?code=12345&state=\(state)")!) { result in
            XCTAssertEqual(result, .failure(.missingExpectedMFA))
            callbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }
    
    func testResumeLastLoggedInUserWithExistingSession() {
        let session = UserSession(clientId: config.clientId, userTokens: Fixtures.userTokens, updatedAt: Date())
        let mockSessionStorage = MockSessionStorage()
        stub(mockSessionStorage) { mock in
            when(mock.get(forClientId: config.clientId)).thenReturn(session)
        }

        let client = Client(configuration: config, sessionStorage: mockSessionStorage, stateStorage: StateStorage(storage: MockStorage()))
        let user = client.resumeLastLoggedInUser()
        XCTAssertEqual(user, User(session: session, sessionStorage: MockSessionStorage()))
    }
    
    func testResumeLastLoggedInUserWithoutSession() {
        let mockSessionStorage = MockSessionStorage()
        stub(mockSessionStorage) { mock in
            when(mock.get(forClientId: config.clientId)).thenReturn(nil)
        }

        let client = Client(configuration: config, sessionStorage: mockSessionStorage, stateStorage: StateStorage(storage: MockStorage()))
        XCTAssertNil(client.resumeLastLoggedInUser())
    }
    
    func testSimplifiedLoginDataWithExistingSession() {
        let now = Date()
        let newestSession = UserSession(clientId: config.clientId, userTokens: Fixtures.userTokens, updatedAt: now)
        let earlierSession = UserSession(clientId: "other client", userTokens: Fixtures.userTokens, updatedAt: now.addingTimeInterval(-1000))
        let mockSessionStorage = MockSessionStorage()
        stub(mockSessionStorage) { mock in
            when(mock.getAll()).thenReturn([newestSession, earlierSession])
        }

        let client = Client(configuration: config, sessionStorage: mockSessionStorage, stateStorage: StateStorage(storage: MockStorage()))
        let result = client.simplifiedLoginData()
        XCTAssertEqual(result, SimplifiedLoginData(uuid: newestSession.userTokens.idTokenClaims.sub, client: newestSession.clientId))
    }
    
    func testSimplifiedLoginDataWithoutSession() {
        let mockSessionStorage = MockSessionStorage()
        stub(mockSessionStorage) { mock in
            when(mock.getAll()).thenReturn([])
        }
        
        XCTAssertNil(Client(configuration: config, sessionStorage: mockSessionStorage, stateStorage: StateStorage(storage: MockStorage())).simplifiedLoginData())
    }
    
    func testPerformSimplifiedLogin() {
        let session = UserSession(clientId: "anyClientId", userTokens: Fixtures.userTokens, updatedAt: Date())
        let mockSessionStorage = MockSessionStorage()
        stub(mockSessionStorage) { mock in
            when(mock.getAll()).thenReturn([session])
            when(mock.store(any())).thenDoNothing()
        }

        let idTokenClaims = IdTokenClaims(sub: "userUuid", nonce: nil, amr: nil)
        let idToken = createIdToken(claims: idTokenClaims)
        let tokenResponse = TokenResponse(access_token: "otherAccessToken", refresh_token: "otherRefreshToken", id_token: idToken, scope: "openid", expires_in: 3600)
        let mockHTTPClient = MockHTTPClient()
        stub(mockHTTPClient) { mock in
            when(mock.post(url: equal(to: config.serverURL.appendingPathComponent("/api/2/oauth/exchange")),
                           body: any(),
                           contentType: HTTPUtil.xWWWFormURLEncodedContentType,
                           authorization: "Bearer \(Fixtures.userTokens.accessToken)",
                           completion: anyClosure()))
                .then { _, _, _, _, completion in
                    completion(.success(SchibstedAccountAPIResponse(data: OAuthCodeExchangeResponse(code: "authCode"))))
                }

            when(mock.post(url: equal(to: config.serverURL.appendingPathComponent("/oauth/token")),
                           body: any(),
                           contentType: HTTPUtil.xWWWFormURLEncodedContentType,
                           authorization: HTTPUtil.basicAuth(username: config.clientId, password: config.clientSecret),
                           completion: anyClosure()))
                .then { _, _, _, _, completion in
                    completion(.success(tokenResponse))
                }
            let jwksResponse = JWKSResponse(keys: [RSAJWK(kid: ClientTests.keyId, kty: "RSA", e: ClientTests.jwsUtil.publicJWK.exponent, n: ClientTests.jwsUtil.publicJWK.modulus, alg: "RS256", use: "sig")])
            when(mock.get(url: equal(to: config.serverURL.appendingPathComponent("/oauth/jwks")), completion: anyClosure()))
                .then { _, completion in
                    completion(.success(jwksResponse))
                }
        }
        
        let callbackExpectation = expectation(description: "Returns logged-in user to callback closure")
        
        let client = Client(configuration: config, sessionStorage: mockSessionStorage, stateStorage: StateStorage(storage: MockStorage()), httpClient: mockHTTPClient)
        client.performSimplifiedLogin { result in
            let user = User(sessionStorage: MockSessionStorage(),
                            clientId: self.config.clientId,
                            accessToken: tokenResponse.access_token,
                            refreshToken: tokenResponse.refresh_token,
                            idToken: idToken,
                            idTokenClaims: idTokenClaims)
            XCTAssertEqual(result, .success(user))
            callbackExpectation.fulfill()
        }

        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }
    
    func testPerformSimplifiedLoginWithoutSession() {
        let mockSessionStorage = MockSessionStorage()
        stub(mockSessionStorage) { mock in
            when(mock.getAll()).thenReturn([])
        }

        let client = Client(configuration: config, sessionStorage: mockSessionStorage, stateStorage: StateStorage(storage: MockStorage()))
        client.performSimplifiedLogin { result in
            XCTAssertEqual(result, .failure(.unexpectedError(message: "No user sessions found")))
        }
    }

    private func createIdToken(claims: IdTokenClaims) -> String {
        let data = try! JSONEncoder().encode(claims)
        return ClientTests.jwsUtil.createJWS(payload: data, keyId: ClientTests.keyId)
    }
}
