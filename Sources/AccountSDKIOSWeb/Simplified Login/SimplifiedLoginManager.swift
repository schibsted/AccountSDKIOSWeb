import UIKit

public final class SimplifiedLoginManager {
    public enum SimplifiedLoginError: Error {
        case noLoggedInSessionInSharedKeychain
    }
    
    private let isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    
    var keychainSessionStorage: SessionStorage?
    let client: Client
    var dataFetcher: SimplifiedLoginDataFetching?
    
    // Properties for building SimplifiedLoginViewController
    let withMFA: MFAType?
    let loginHint: String?
    let extraScopeValues: Set<String>
    let completion: LoginResultHandler
    var withSSO: Bool = true
    
    @available(iOS, obsoleted: 13, message: "This function should not be used in iOS version 13 and above")
    public init(accessGroup: String,
                client: Client,
                withMFA: MFAType? = nil,
                loginHint: String? = nil,
                extraScopeValues: Set<String> = [],
                completion: @escaping LoginResultHandler) {
        self.keychainSessionStorage = KeychainSessionStorage(service: Client.keychainServiceName, accessGroup: accessGroup)
        self.client = client
        
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
        
        self.withMFA = withMFA
        self.loginHint = loginHint
        self.extraScopeValues = extraScopeValues
        self.completion = completion
        self.withSSO = withSSO
    }
}

extension SimplifiedLoginManager {
    /**
     Prepere and configure Simplified Login View Controller which should be shown modaly

     - parameter visibleClientName: optional client name visibile in footer view of Simplified Login. Bundle application name is used by default
     - parameter completion: callback that receives the UIViewController for Simplified Login or an error in case of failure
     */
    public func getSimplifiedLogin(_ visibleClientName: String? = nil, completion: @escaping (Result<UIViewController, Error>) -> Void) {
        guard let latestUserSession = self.keychainSessionStorage?.getLatestSession() else {
            completion(.failure(SimplifiedLoginError.noLoggedInSessionInSharedKeychain))
            return
        }
        
        let user = User(client: client, tokens: latestUserSession.userTokens)
        self.dataFetcher = SimplifiedLoginDataFetcher(user: user)
        self.dataFetcher?.fetch(visibleClientName) { result in
            switch result {
            case .success(let fetchedData):
                DispatchQueue.main.async {
                    let simplifiedLoginViewController = self.makeViewController(fetchedData)
                    completion(.success(simplifiedLoginViewController))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func makeViewController(_ simplifiedLoginData: SimplifiedLoginFetchedData) -> UIViewController {
        let simplifiedLoginViewController: UIViewController
        if #available(iOS 13.0, *) {
            simplifiedLoginViewController = SimplifiedLoginUIFactory.buildViewController(client: self.client,
                                                                                         userContext: simplifiedLoginData.context,
                                                                                         userProfileResponse: simplifiedLoginData.profile,
                                                                                         visibleClientName: simplifiedLoginData.visibleClientName,
                                                                                         withMFA: self.withMFA,
                                                                                         loginHint: self.loginHint,
                                                                                         extraScopeValues: self.extraScopeValues,
                                                                                         withSSO: self.withSSO,
                                                                                         completion: self.completion)
        } else {
            simplifiedLoginViewController = SimplifiedLoginUIFactory.buildViewController(client: self.client,
                                                                                         userContext: simplifiedLoginData.context,
                                                                                         userProfileResponse: simplifiedLoginData.profile,
                                                                                         visibleClientName: simplifiedLoginData.visibleClientName,
                                                                                         withMFA: self.withMFA,
                                                                                         loginHint: self.loginHint,
                                                                                         extraScopeValues: self.extraScopeValues,
                                                                                         completion: self.completion)
        }
        if self.isPad {
            simplifiedLoginViewController.modalPresentationStyle = .formSheet
            simplifiedLoginViewController.preferredContentSize = .init(width: 450, height: 424)
        }
        
        return simplifiedLoginViewController
    }
}
