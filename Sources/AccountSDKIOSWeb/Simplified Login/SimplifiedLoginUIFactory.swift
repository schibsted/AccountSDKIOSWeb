import UIKit
import AuthenticationServices

struct SimplifiedLoginUIFactory {

    @available(iOS, obsoleted: 13, message: "This function should not be used in iOS version 13 and above")
    static func buildViewController(client: Client,
                                    assertionFetcher: SimplifiedLoginFetching,
                                    userContext: UserContextFromTokenResponse,
                                    userProfileResponse: UserProfileResponse,
                                    clientName: String,
                                    withMFA: MFAType? = nil,
                                    loginHint: String? = nil,
                                    extraScopeValues: Set<String> = [],
                                    completion: @escaping LoginResultHandler) -> UIViewController {
        
        let imageDataModel = ConcreteSimplifiedLoginNamedImageData(env: client.configuration.env)
        let userDataModel = ConcreteSimplifiedLoginUserData(userContext: userContext, userProfileResponse: userProfileResponse)
        let localizationModel = SimplifiedLoginLocalizationModel()
        
        let viewModel = SimplifiedLoginViewModel(imageDataModel: imageDataModel, userDataModel: userDataModel, localizationModel: localizationModel, visibleClientName: clientName)
        
        viewModel.onClickedSwitchAccount = { // TODO: need to be tested with iOS 12
            viewModel.asWebAuthenticationSession = client.getLoginSession(withMFA: withMFA,
                                                                          loginHint: loginHint,
                                                                          extraScopeValues: extraScopeValues,
                                                                          completion: completion)
            viewModel.asWebAuthenticationSession?.start()
        }
        
        return commonSetup(completion: completion, client: client, assertionFetcher: assertionFetcher, viewModel: viewModel)
    }
    
    @available(iOS 13.0, *)
    static func buildViewController(client: Client,
                                    contextProvider: ASWebAuthenticationPresentationContextProviding,
                                    assertionFetcher: SimplifiedLoginFetching,
                                    userContext: UserContextFromTokenResponse,
                                    userProfileResponse: UserProfileResponse,
                                    clientName: String,
                                    withMFA: MFAType? = nil,
                                    loginHint: String? = nil,
                                    extraScopeValues: Set<String> = [],
                                    withSSO: Bool = true,
                                    completion: @escaping LoginResultHandler) -> UIViewController {
       
        let imageDataModel = ConcreteSimplifiedLoginNamedImageData(env: client.configuration.env)
        let userDataModel = ConcreteSimplifiedLoginUserData(userContext: userContext, userProfileResponse: userProfileResponse)
        let localizationModel = SimplifiedLoginLocalizationModel()
        let viewModel = SimplifiedLoginViewModel(imageDataModel: imageDataModel, userDataModel: userDataModel, localizationModel: localizationModel, visibleClientName: clientName)
        
        viewModel.onClickedSwitchAccount = {
            let context = ASWebAuthSessionContextProvider()
            viewModel.asWebAuthenticationSession = client.getLoginSession(contextProvider: context,
                                                                          withMFA: withMFA,
                                                                          loginHint: loginHint,
                                                                          extraScopeValues: extraScopeValues,
                                                                          withSSO: withSSO,
                                                                          completion: completion)
            viewModel.asWebAuthenticationSession?.start()
        }
        
        return commonSetupIOS13(contextProvider: contextProvider, completion: completion, client: client, assertionFetcher: assertionFetcher, viewModel: viewModel)
    }
    
    @available(iOS 13.0, *)
    private static func commonSetupIOS13(contextProvider: ASWebAuthenticationPresentationContextProviding, completion: @escaping LoginResultHandler, client: Client, assertionFetcher: SimplifiedLoginFetching,  viewModel: SimplifiedLoginViewModel) -> UIViewController {
        let s = SimplifiedLoginViewController(viewModel: viewModel )
        let nc = UINavigationController()
        nc.pushViewController(s, animated: false)
        
        let url = URL(string: viewModel.localizationModel.privacyPolicyURL)!
        let webVC = WebViewController()
        
        viewModel.onClickedContinueWithoutLogin = {
            nc.dismiss(animated: true, completion: nil)
        }
        
        viewModel.onClickedPrivacyPolicy = {
            webVC.loadURL(url)
            nc.pushViewController(webVC, animated: true)
        }
        
        viewModel.onClickedContinueAsUser = {
            assertionFetcher.fetchAssertion { result in
                switch result {
                case .success(let assertion):
                    DispatchQueue.main.async {
                        let session = client.createWebAuthenticationSession(withMFA: nil, loginHint: nil, assertion: assertion.assertion, extraScopeValues: [], completion: completion)
                        viewModel.asWebAuthenticationSession = session
                        
                        if #available(iOS 13.0, *) {
                            session.presentationContextProvider = contextProvider //TODO: Perhaps should be passed in
                            session.prefersEphemeralWebBrowserSession = true
                        }
                        
                        session.start()
                    }
                case .failure(let error):
                    SchibstedAccountLogger.instance.error("Failed to fetch assertion on Simplified login flow: \(error)")
                    completion(.failure(LoginError.unexpectedError(message: "Failed to obtain Assertion")))
                }
            }
        }
        
        return nc
    }
    
    private static func commonSetup(completion: @escaping LoginResultHandler, client: Client, assertionFetcher: SimplifiedLoginFetching,  viewModel: SimplifiedLoginViewModel) -> UIViewController {
        let s = SimplifiedLoginViewController(viewModel: viewModel )
        let nc = UINavigationController()
        nc.pushViewController(s, animated: false)
        
        let url = URL(string: viewModel.localizationModel.privacyPolicyURL)!
        let webVC = WebViewController()
        
        viewModel.onClickedContinueWithoutLogin = {
            nc.dismiss(animated: true, completion: nil)
        }
        
        viewModel.onClickedPrivacyPolicy = {
            webVC.loadURL(url)
            nc.pushViewController(webVC, animated: true)
        }
        
        viewModel.onClickedContinueAsUser = {
            assertionFetcher.fetchAssertion { result in
                switch result {
                case .success(let assertion):
                    DispatchQueue.main.async {
                        let session = client.createWebAuthenticationSession(withMFA: nil, loginHint: nil, assertion: assertion.assertion, extraScopeValues: [], completion: completion)
                        viewModel.asWebAuthenticationSession = session
                        
                        if #available(iOS 13.0, *) {
                            let context = ASWebAuthSessionContextProvider()
                            session.presentationContextProvider = context //TODO: Perhaps should be passed in
                            session.prefersEphemeralWebBrowserSession = true
                        }
                        
                        session.start()
                    }
                case .failure(let error):
                    SchibstedAccountLogger.instance.error("Failed to fetch assertion on Simplified login flow: \(error)")
                    completion(.failure(LoginError.unexpectedError(message: "Failed to obtain Assertion")))
                }
            }
        }
        
        return nc
    }
}
