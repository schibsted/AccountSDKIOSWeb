# Schibsted account iOS SDK

[![Build Status](https://github.com/schibsted/account-sdk-ios-web/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/schibsted/account-sdk-ios-web/actions/workflows/ci.yml)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/schibsted/account-sdk-ios-web)
![Platform](https://img.shields.io/badge/Platform-iOS%2012.0%2B-orange.svg?style=flat)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/schibsted/account-sdk-ios-web/blob/master/LICENSE)


New implementation of the Schibsted account iOS SDK using the web flows via 
[`ASWebAuthenticationSession`](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession).

API documentation can be found [here](https://schibsted.github.io/account-sdk-ios-web/).

## Getting started

To implement login with Schibsted account in your app, please first have a look at our
[getting started documentation](https://docs.schibsted.io/schibsted-account/gettingstarted/).
This will help you create a client and configure the necessary data.

**Note:** This SDK requires your client to be registered as a `public_mobile_client` in Self Service (see [getting started documentation](https://docs.schibsted.io/schibsted-account/gettingstarted/) for more help).
  
### Requirements

* iOS 12.0+

### Installation

Swift Package Manager: `.package(url: "https://github.com/schibsted/account-sdk-ios-web")`

CocoaPods `pod 'AccountSDKIOSWeb'`

### Usage

#### Login user and fetch profile data

```swift
let clientConfiguration = ClientConfiguration(environment: .pre,
                                              clientId: clientId,
                                              redirectURI: redirectURI)
let client = Client(configuration: clientConfiguration) 
let contextProvider = ASWebAuthSessionContextProvider()
let asWebAuthSession = client.getLoginSession(contextProvider: contextProvider, withSSO: true, completion: { result in
    switch result {
    case .success(let user):
        print("Success - logged in as \(String(describing: user.uuid))")
        self.user = user
    case .failure(let error):
        print(error)
    }

    user.fetchProfileData { result in
        switch result {
        case .success(let userData):
            print(userData)
        case .failure(let error):
            print(error)
        }
    }
})

asWebAuthSession.start()
```

#### Get notified on logout

```swift
let userDelegate: UserDelegate = MyUserDelegate()
user?.delegates.addDelegate(userDelegate)
self.userDelegate = userDelegate // Needs to be retained

class MyUserDelegate: UserDelegate {
    func userDidLogout() {
        print("Callback will be invoked when user is logged out")
    }
}
```

### Notes on using custom URI schemes

When using custom URI as redirect URI, the OS handles opening the app associated with the link instead of triggering the `ASWebAuthenticationSession` callback.
It results in the `ASWebAuthenticationSession` view not being closed properly, which instead needs to be done manually:

1. Get a reference to `ASWebAuthenticationSession` and start it:
    ```swift
    func handleLoginResult(_ result: Result<User, LoginError>) {
        switch result {
        case .success(let user):
            print("Success - logged-in as \(user.uuid)!")
            self.user = user
        case .failure(let error):
            print(error)
        }
    }

    let contextProvider = ASWebAuthSessionContextProvider()
    asWebAuthSession = client.getLoginSession(contextProvider: contextProvider, withSSO: true, completion: handleLoginResult)
    asWebAuthSession.start() // this will trigger the web context asking the user to login
    ```
2. Handle the response as an incoming URL, e.g. via your app's delegate `application(_:open:options:)`:
    ```swift
    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplicationOpenURLOptionsKey : Any] = [:] ) -> Bool {
        client.handleAuthenticationResponse(url: url) { result in
            DispatchQueue.main.async {
                asWebAuthSession.cancel() // manually close the ASWebAuthenticationSession
            }
            handleLoginResult(result)
        }
    }
    ```
    
3. When implementing **Swedish BankID** authentication the parent app must catch the redirect URI and return with no action. Please make sure that `handleAuthenticationResponse` is not called for the BankID redirect. The URI scheme that is used to redirect back to the parent app from BankID will have the following format: `{app_uri_scheme}:/bankId`. Find below a code example:
    ```swift
    func handleOnOpenUrl(url: URL) {
        if url.pathComponents.contains("bankId") {
            return
        }
        
        client.handleAuthenticationResponse(url: url) { result in
            DispatchQueue.main.async {
                asWebAuthSession.cancel() // manually close the ASWebAuthenticationSession
            }
            handleLoginResult(result)
        }
    }
    ```
    
### Obtaining tokens externally

Tokens can be obtained externally and injected into SDK for the already created users. This can be useful in the case of a test scenario.
To do this, first you need to start the web login flow with the request as follow:

```sh
GET "${BASE_URL}/oauth/authorize?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=openid%20offline_access&state=${state}&nonce=${nonce}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256&prompt=select_account"
```
where: 
`BASE_URL` - base URL of Schibsted Account environment
`client_id` - public mobile client id
`redirect_uri` - redirect URI for given client
`state` -  A string value sent by the client that protects end user from CSRF attacks. It's a randomly generated string of 10 characters (both letters and numbers)
`nonce` - A string value sent by the client that is included in the resulting ID token as a claim. The client must then verify this value to mitigate token replay attacks. It's a randomly generated string of 10 characters (both letters and numbers)
`code_challenge` - [`PKCE`](https://www.oauth.com/oauth2-servers/pkce/) calculated from `code_verifier`

On the finish, web flow returns URL with query parameters `state` and `code`. 
Tokens can be obtained with the following request:

```sh
curl {BASE_URL}/oauth/token \
   -X POST \
   -H "X-OIDC: v1" \
   -d "client_id={client_id}" \
   -d "grant_type=authorization_code" \
   -d "code={code_from_login_flow}" \
   -d "code_verifier={code_verifier}" \
   -d "redirect_uri={redirect_uri}"
```
   where `code_verifier` is the same which was used for calculating `code_challenge`. It can be a randomly generated string of 60 characters (both letters and numbers)


### Configuring logging
This SDK uses [`SwiftLog`](https://github.com/apple/swift-log), allowing you to easily customise the logging.
The logger can be modified, for example to change the log level, via the following code:
```swift
SchibstedAccountLogger.instance.logLevel = .debug
```

## How it works

This SDK implements the [best practices for user authentication via an OpenID Connect identity provider](https://tools.ietf.org/html/rfc8252):

* It uses [`ASWebAuthenticationSession`](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession).
  This allows for single-sign on between apps, with the user being recognized as a returning user to Schibsted account via cookies.
  On iOS 13 and above this behavior can be disabled, which also removes the extra user prompt about allowing to use Schibsted account for login, using
  `withSSO: false` in `Client.getLoginSession(withMFA:loginHint:extraScopeValues:withSSO:completion:)`.
* After the completed user authentication, user tokens are obtained and stored securely in the keychain storage.
    * The ID Token is validated according to the [specification](https://openid.net/specs/openid-connect-core-1_0.html#IDTokenValidation).
      The signature of the ID Token (which is a [JWS](https://datatracker.ietf.org/doc/html/rfc7515)) is verified by the library [`JOSESwift`](https://github.com/airsidemobile/JOSESwift).
    * Authenticated requests to backend services can be done via
      `AuthenticatedURLSession.dataTask(with: URLRequest, completionHandler: ...` 
      The SDK will automatically inject the user access token as a Bearer token in the HTTP
      Authorization request header.
      If the access token is rejected with a `401 Unauthorized` response (e.g. due to having
      expired), the SDK will try to use the refresh token to obtain a new access token and then
      retry the request once more.

      **Note:** If the refresh token request fails, due to the refresh token itself having expired
      or been invalidated by the user, the SDK will log the user out.
* Upon opening the app, the last logged-in user can be resumed by the SDK by trying to read previously stored tokens from the keychain storage. This will be handled by once invoking `Client.resumeLastLoggedInUser(completion: @escaping (User?) -> Void)` upon app start.

## Simplified Login

### Configuring Simplified Login
Prerequisite: Applications need to be on the same Apple Development account in order to have access to the shared keychain. 

1. In your application target, add Keychain Sharing capability with keychain group set to `com.schibsted.simplifiedLogin`.
2. Creating client, pass additional parameter `appIdentifierPrefix`. It is usually the same as team identifier prefix - 10 characters combination of both numbers and letters assigned by Apple.

```swift
let client = Client(configuration: clientConfiguration, appIdentifierPrefix: "xxxxxxxxxx") 
```

3. Create `SimplifiedLoginManager` and call `getSimplifiedLogin` method anytime you want to present SL to user.

```swift
    let context = ASWebAuthSessionContextProvider()
    let manager = SimplifiedLoginManager(client: client, contextProvider: context, env: clientConfiguration.env) { result in
            print("Catch login result \(result)")
    }
    manager.requestSimplifiedLogin() { result in
        switch (result) {
        case .success():
            print("success")
        case .failure(let error):
            print("Catch error from presenting SL \(error)")
        }
    }
```

If you want to present Simplified Login UI on a specific UIWindow, you need to pass the optional parameter `window` calling `requestSimplifiedLogin` method.

### Tracking

The Account SDK does some internal tracking (mostly for the Simplified Login) and allows a `TrackingEventsHandler` to be set during the Client's initialization.
To fulfill this, you can either implement it yourself or use one which is already implemented.

**Internal**: There is an internal Schibsted Tracking implementation for the identity SDK available [here](https://github.schibsted.io/spt-identity/identity-sdk-ios-tracking) It integrates the latest Account SDK with the latest Pulse Tracking SDK for iOS.

#### Localization

Simplified Login comes with the following localization support:

1. 🇳🇴 Norwegian Bokmål
1. 🇸🇪 Swedish
1. 🇫🇮 Finnish
1. 🇩🇰 Danish
1. 🇬🇧 English (Default)

## Local development

### Setup

#### Prerequisites
1. All you need is Xcode with command-line tools installed. It works perfectly with version 13.4.1.

#### Steps
1. Clone repository
1. Open `workspace.xcworkspace` file, which exists in the Projects folder. It contains two projects inside: AccountSDKIOSWeb which is the SDK itself, and ExampleWeb which serves as a demo application.
1. To run the demo application on the simulator, choose the ExampleWeb scheme and target your choices like an iPhone or iPad. Run the application with the play button or press `command + R`. 
1. If Xcode fails to resolve package dependency, click on them and resolve them manually. 

#### Unit tests

1. There are two schemes with tests. To run unit tests, select one of them and press `command + U`

### How to release the SDK

#### Prerequisites

1. To successfully release the SDK's pod to the CocoaPods repository, you need first set up the pod trunk on your computer. See https://guides.cocoapods.org/making/getting-setup-with-trunk.html. 
1. You should be added as an owner to the library in the CocoaPods repository. Please ask the User Access team, who can give you the correct rights.

#### Steps to release

1. Make sure all changes going in the release have been merged to the `master` branch.
1. Update new SDK version number in both [Version.swift](https://github.com/schibsted/account-sdk-ios-web/blob/master/Sources/AccountSDKIOSWeb/Lib/Version.swift) and [AccountSDKIOSWeb.podspec](AccountSDKIOSWeb.podspec) files. Commit this change to the `master` branch.
1. Create a new [release via GitHub](https://github.com/schibsted/account-sdk-ios/releases).
    1. Enter the version number as the tag name, and include all important changes in the release description.
1. Publish the pod by running `pod trunk push AccountSDKIOSWeb.podspec` from your local machine.
