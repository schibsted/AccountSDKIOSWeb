# Schibsted account iOS SDK

[![Build Status](https://app.travis-ci.com/schibsted/account-sdk-ios-web.svg?branch=master)](https://app.travis-ci.com/schibsted/account-sdk-ios-web)
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

**Note:** If you have implemented the [Old Schibsted SDK](https://github.com/schibsted/account-sdk-ios) in your app, and want these users to remain logged in, do not forget to add the SessionStorageConfig on instantiating your Client, `Client(configuration:sessionStorageConfig:httpClient:)`.   
  
### Requirements

* iOS 12.0+

### Installation

Swift Package Manager: `.package(url: "https://github.com/schibsted/account-sdk-ios-web")`

CocoaPods `pod 'AccountSDKIOSWeb', '~> 2.2.0'`

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
1. Handle the response as an incoming URL, e.g. via your app's delegate `application(_:open:options:)`:
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
`state` - randomly generated string of 10 characters (letters and numbers)
`nonce` - randomly generated string of 10 characters (letters and numbers)
`code_challenge` - [`PKCE`](https://www.oauth.com/oauth2-servers/pkce/) calculated from code_verifier

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
   where `code_verifier` is the same which was used for calculating `code_challenge`


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
* Upon opening the app, the last logged-in user can be resumed by the SDK by trying to read previously stored tokens from the keychain storage.
