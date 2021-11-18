import UIKit

public struct SimplifiedLoginUIFactory {

    @available(iOS, obsoleted: 13, message: "This function should not be used in iOS version 13 and above")
    public static func buildViewController(client: Client,
                                           env: ClientConfiguration.Environment, // TODO: Currently used to decide language.
                                           withMFA: MFAType? = nil,
                                           loginHint: String? = nil,
                                           extraScopeValues: Set<String> = [],
                                           completion: @escaping LoginResultHandler) -> UIViewController {
        
        let viewModel = SimplifiedLoginViewModel(client: client, env: env)! // TODO: throw error
        viewModel.onClickedSwitchAccount = { // TODO: need to be tested with iOS 12
            viewModel.asWebAuthenticationSession = client.getLoginSession(withMFA: withMFA,
                                                                          loginHint: loginHint,
                                                                          extraScopeValues: extraScopeValues,
                                                                          completion: completion) //
            viewModel.asWebAuthenticationSession?.start()
        }
        
        return commonSetup(viewModel: viewModel)
    }
    
    @available(iOS 13.0, *)
    public static func buildViewController(client: Client,
                                           env: ClientConfiguration.Environment, // TODO: Currently used to decide language.
                                           withMFA: MFAType? = nil,
                                           loginHint: String? = nil,
                                           extraScopeValues: Set<String> = [],
                                           withSSO: Bool = true,
                                           completion: @escaping LoginResultHandler) -> UIViewController {
        let viewModel = SimplifiedLoginViewModel(client: client, env: env)! // TODO: throw error
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
        
        return commonSetup(viewModel: viewModel)
    }
    
    private static func commonSetup(viewModel: SimplifiedLoginViewModel) -> UIViewController {
        let s = SimplifiedLoginViewController(viewModel: viewModel )
        let nc = UINavigationController()
        nc.pushViewController(s, animated: false)
        
        viewModel.onClickedContinueAsUser = {} // TODO:
        
        viewModel.onClickedContinueWithoutLogin = {
            nc.dismiss(animated: true, completion: nil)
        }
        
        viewModel.onClickedPrivacyPolicy = { // TODO: Connect so that the text is a button or something else actionable
            let url = URL(string: viewModel.localisation.privacyPolicyURL)!
            let webVC = WebViewController(url: url)
            nc.pushViewController(webVC, animated: false)
        }
        
        return nc
    }
}
