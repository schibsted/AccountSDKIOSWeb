import UIKit

public final class SimplifiedLoginManager {
    public enum SimplifiedLoginError: Error {
        case noOtherLoggedInSession
    }
    
    var keychainSessionStorage: KeychainSessionStorage?
    let client: Client
    var user: User?
    
    // Properties for building SimplifiedLoginViewController
    let env: ClientConfiguration.Environment
    let withMFA: MFAType?
    let loginHint: String?
    let extraScopeValues: Set<String>
    let completion: LoginResultHandler
    var withSSO: Bool = true
    
    @available(iOS, obsoleted: 13, message: "This function should not be used in iOS version 13 and above")
    public init(accessGroup: String,
                client: Client,
                env: ClientConfiguration.Environment, // TODO: Currently used to decide language.
                withMFA: MFAType? = nil,
                loginHint: String? = nil,
                extraScopeValues: Set<String> = [],
                completion: @escaping LoginResultHandler) {
        self.keychainSessionStorage = KeychainSessionStorage(service: Client.keychainServiceName, accessGroup: accessGroup)
        self.client = client
        
        self.env = env
        self.withMFA = withMFA
        self.loginHint = loginHint
        self.extraScopeValues = extraScopeValues
        self.completion = completion
    }
    
    @available(iOS 13.0, *)
    public init(accessGroup: String,
                client: Client,
                env: ClientConfiguration.Environment, // TODO: Currently used to decide language.
                withMFA: MFAType? = nil,
                loginHint: String? = nil,
                extraScopeValues: Set<String> = [],
                withSSO: Bool = true,
                completion: @escaping LoginResultHandler) {
        self.keychainSessionStorage = KeychainSessionStorage(service: Client.keychainServiceName, accessGroup: accessGroup)
        self.client = client
        
        self.env = env
        self.withMFA = withMFA
        self.loginHint = loginHint
        self.extraScopeValues = extraScopeValues
        self.completion = completion
        self.withSSO = withSSO
    }
    
    // MARK:
    
    public func getSimplifiedLogin(completion: @escaping (Result<UIViewController, Error>) -> Void) throws {
        let latestUserSession = self.keychainSessionStorage?.getAll()
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        
        guard let latestUserSession = latestUserSession else {
            throw SimplifiedLoginError.noOtherLoggedInSession // TODO: This  could also be a missing entitlement error.
        }
        
        let user = User(client: client, tokens: latestUserSession.userTokens)
        self.user = user
        
        user.userContextFromToken { result in
            switch result {
            case .success(let userContextResponse):
                self.fetchProfile( userContext: userContextResponse, completion: completion)
            case .failure(let error):
                print("Some error happened \(error)")
                completion(.failure(error))
            }
        }
    }
    
    private func fetchProfile(userContext: UserContextFromTokenResponse, completion: @escaping (Result<UIViewController, Error>) -> Void) {
        self.user?.fetchProfileData { result in
            switch result {
            case .success(let profileResponse): // TODO: profileResponse and userContext need to be passed to factory when building SimplifiedLogin ViewController
                let simplifiedLoginViewController: UIViewController
                if #available(iOS 13.0, *) {
                    simplifiedLoginViewController = SimplifiedLoginUIFactory.buildViewController(client: self.client,
                                                                                                 env: self.env,
                                                                                                 withMFA: self.withMFA,
                                                                                                 loginHint: self.loginHint,
                                                                                                 extraScopeValues: self.extraScopeValues,
                                                                                                 withSSO: self.withSSO,
                                                                                                 completion: self.completion)
                } else {
                    simplifiedLoginViewController = SimplifiedLoginUIFactory.buildViewController(client: self.client,
                                                                                                 env: self.env,
                                                                                                 withMFA: self.withMFA,
                                                                                                 loginHint: self.loginHint,
                                                                                                 extraScopeValues: self.extraScopeValues,
                                                                                                 completion: self.completion)
                }
                
                completion(.success(simplifiedLoginViewController))
            case .failure(let error):
                print("Some error happened \(error)")
                completion(.failure(error))
            }
        }
    }
}
