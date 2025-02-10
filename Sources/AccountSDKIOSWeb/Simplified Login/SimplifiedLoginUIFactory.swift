//
// Copyright © 2022 Schibsted.
// Licensed under the terms of the MIT license. See LICENSE in the project root.
//

import UIKit
import AuthenticationServices
import SafariServices

struct SimplifiedLoginUIFactory {

    @available(iOS, deprecated: 13, message: "This function should not be used in iOS version 13 and above")
    // swiftlint:disable function_body_length
    static func buildViewController(client: Client,
                                    assertionFetcher: SimplifiedLoginFetching,
                                    userContext: UserContextFromTokenResponse,
                                    userProfileResponse: UserProfileResponse,
                                    window: UIWindow? = nil,
                                    withMFA: MFAType? = nil,
                                    state: String? = nil,
                                    loginHint: String? = nil,
                                    extraScopeValues: Set<String> = [],
                                    completion: @escaping LoginResultHandler) -> UIViewController {

        FontManager.registerFonts()
        let imageDataModel = ConcreteSimplifiedLoginNamedImageData(env: client.configuration.env)
        let userDataModel = ConcreteSimplifiedLoginUserData(userContext: userContext,
                                                            userProfileResponse: userProfileResponse)
        let localizationModel = SimplifiedLoginLocalizationModel()

        let viewModel = SimplifiedLoginViewModel(imageDataModel: imageDataModel,
                                                 userDataModel: userDataModel,
                                                 localizationModel: localizationModel,
                                                 tracker: client.tracker)

        let viewController = window?.visibleViewController
        let extendedCompletion: LoginResultHandler = { result in
            // Do not dismiss SimplifiedLoginViewController when user cancels web login flow.
            if Result.failure(LoginError.canceled) != result {
                DispatchQueue.main.async {
                    viewController?.dismiss(animated: true, completion: nil)
                }
            }
            completion(result)
        }

        viewModel.onClickedSwitchAccount = {
            viewModel.asWebAuthenticationSession = client.getLoginSession(withMFA: withMFA,
                                                                          state: state,
                                                                          loginHint: loginHint,
                                                                          extraScopeValues: extraScopeValues,
                                                                          completion: extendedCompletion)
            viewModel.asWebAuthenticationSession?.start()
        }

        viewModel.onClickedContinueAsUser = {
            assertionFetcher.fetchAssertion(clientId: client.configuration.clientId) { result in
                switch result {
                case .success(let assertion):
                    DispatchQueue.main.async {
                        if let session = client.createWebAuthenticationSession(withMFA: nil,
                                                                               state: nil,
                                                                               loginHint: nil,
                                                                               assertion: assertion.assertion,
                                                                               extraScopeValues: [],
                                                                               completion: extendedCompletion) {
                            session.start()
                        } else {
                            SchibstedAccountLogger.instance.error("Could not start authentication session")
                            client.tracker?.error(.loginError(.previousSessionInProgress), in: .simplifiedLogin)
                            completion(.failure(LoginError.previousSessionInProgress))
                        }
                    }
                case .failure(let error):
                    SchibstedAccountLogger.instance
                        .error("Failed to fetch assertion on Simplified login flow: \(error)")
                    let error = LoginError.unexpectedError(message: "Failed to obtain Assertion")
                    client.tracker?.error(.loginError(error), in: .simplifiedLogin)
                    completion(.failure(error))
                }
            }
        }

        return commonSetup(client: client,
                           viewModel: viewModel,
                           assertionFetcher: assertionFetcher,
                           completion: completion)
    }

    @available(iOS 13.0, *)
    // swiftlint:disable function_parameter_count
    static func buildViewController(client: Client,
                                    contextProvider: ASWebAuthenticationPresentationContextProviding,
                                    assertionFetcher: SimplifiedLoginFetching,
                                    userContext: UserContextFromTokenResponse,
                                    userProfileResponse: UserProfileResponse,
                                    window: UIWindow? = nil,
                                    withMFA: MFAType? = nil,
                                    state: String? = nil,
                                    loginHint: String? = nil,
                                    extraScopeValues: Set<String> = [],
                                    withSSO: Bool = true,
                                    completion: @escaping LoginResultHandler) -> UIViewController {

        FontManager.registerFonts()
        let imageDataModel = ConcreteSimplifiedLoginNamedImageData(env: client.configuration.env)
        let userDataModel = ConcreteSimplifiedLoginUserData(
            userContext: userContext,
            userProfileResponse: userProfileResponse)
        let localizationModel = SimplifiedLoginLocalizationModel()
        let viewModel = SimplifiedLoginViewModel(
            imageDataModel: imageDataModel,
            userDataModel: userDataModel,
            localizationModel: localizationModel,
            tracker: client.tracker)

        let viewController = window?.visibleViewController
        let extendedCompletion: LoginResultHandler = { result in
            // Do not dismiss SimplifiedLoginViewController when user cancels web login flow.
            if Result.failure(LoginError.canceled) != result {
                DispatchQueue.main.async {
                    viewController?.dismiss(animated: true, completion: nil)
                }
            }
            completion(result)
        }

        viewModel.onClickedSwitchAccount = {
            let context = ASWebAuthSessionContextProvider()
            viewModel.asWebAuthenticationSession = client.getLoginSession(contextProvider: context,
                                                                          withMFA: withMFA,
                                                                          state: state,
                                                                          loginHint: loginHint,
                                                                          extraScopeValues: extraScopeValues,
                                                                          withSSO: withSSO,
                                                                          completion: extendedCompletion)
            viewModel.asWebAuthenticationSession?.start()
        }

        viewModel.onClickedContinueAsUser = {
            assertionFetcher.fetchAssertion(clientId: client.configuration.clientId) { result in
                switch result {
                case .success(let assertion):
                    DispatchQueue.main.async {
                        if let session = client.createWebAuthenticationSession(withMFA: nil,
                                                                               state: nil,
                                                                               loginHint: nil,
                                                                               assertion: assertion.assertion,
                                                                               extraScopeValues: [],
                                                                               completion: extendedCompletion) {
                            viewModel.asWebAuthenticationSession = session
                            session.presentationContextProvider = contextProvider
                            session.prefersEphemeralWebBrowserSession = true
                            session.start()
                        } else {
                            SchibstedAccountLogger.instance.error("Could not start authentication session")
                            client.tracker?.error(.loginError(.previousSessionInProgress), in: .simplifiedLogin)
                            completion(.failure(LoginError.previousSessionInProgress))
                        }
                    }
                case .failure(let error):
                    SchibstedAccountLogger.instance
                        .error("Failed to fetch assertion on Simplified login flow: \(error)")
                    let error = LoginError.unexpectedError(message: "Failed to obtain Assertion")
                    client.tracker?.error(.loginError(error), in: .simplifiedLogin)
                    completion(.failure(error))
                }
            }
        }

        return commonSetup(client: client,
                           viewModel: viewModel,
                           assertionFetcher: assertionFetcher,
                           completion: completion)
    }

    private static func commonSetup(client: Client,
                                    viewModel: SimplifiedLoginViewModel,
                                    assertionFetcher: SimplifiedLoginFetching,
                                    completion: @escaping LoginResultHandler) -> UIViewController {
        let viewController = SimplifiedLoginViewController(viewModel: viewModel)
        let url = URL(string: viewModel.localizationModel.privacyPolicyURL)!

        viewModel.onClickedContinueWithoutLogin = {
            viewController.dismiss(animated: true, completion: nil)
        }

        viewModel.onClickedPrivacyPolicy = {
            let svc = SFSafariViewController(url: url)
            viewController.present(svc, animated: true, completion: nil)
        }

        return viewController
    }
}
