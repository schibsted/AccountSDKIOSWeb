import SwiftUI
import WebKit
import AccountSDKIOSWeb
import AuthenticationServices

struct ContentView: View {
    let client: Client
    let clientConfiguration: ClientConfiguration
    
    @State var userDelegate: MyUserDelegate?
    @State private var user: User? {
        didSet {
            let userDelegate = MyUserDelegate()
            userDelegate.onLogout = { print("Callback will be invoked when user is logged out") }
            user?.delegates.addDelegate(userDelegate)
            self.userDelegate = userDelegate // Needs to be retained
        }
    }
    var userIsLoggedIn: Bool {
        get {
            user?.isLoggedIn() ?? false
        }
    }

    @State private var accountPagesURL: URL?
    @State private var showAccountPages = false

    @State private var asWebAuthSession: ASWebAuthenticationSession?

    init(client: Client, clientConfiguration: ClientConfiguration) {
        self.client = client
        self.clientConfiguration = clientConfiguration
    }

    var body: some View {
        NavigationView {
            let webView = WebView(url: $accountPagesURL)

            VStack(spacing: 20) {
                Group {
                    Text(String(describing: client))
                    Text("Logged-in as \(user?.uuid ?? "unknown")")
                }
                
                Button(action: {
                    client.resumeLastLoggedInUser() { user in
                        guard let user = user else {
                            print("User could not be resumed")
                            return
                        }
                        self.user = user
                        print("Resumed user")
                    }
                }) {
                    Text("Resume user")
                }

                Group {
                    Button(action: {
                        let context = ASWebAuthSessionContextProvider()
                        asWebAuthSession = client.getLoginSession(contextProvider: context,
                                                                  withMFA: .otp,
                                                                  withSSO: true,
                                                                  completion: { result in
                            switch result {
                            case .success(let user):
                                print("Success - logged in as \(user.uuid ?? "")")
                                self.user = user
                            case .failure(let error):
                                print(error)
                            }
                        })
                        
                        // This will trigger the web context asking the user to login
                        asWebAuthSession?.start()
       
                    }) {
                        Text("Trigger 2FA (OTP)")
                    }
                    
                    Button(action: {
                        
                        let context = ASWebAuthSessionContextProvider()
                        asWebAuthSession = client.getLoginSession(contextProvider: context,
                                                                  withMFA: .sms,
                                                                  withSSO: true) { result in
                            switch result {
                            case .success(let user):
                                print("Success - logged in as \(user.uuid ?? "")")
                                self.user = user
                            case .failure(let error):
                                print(error)
                            }
                        }
                        asWebAuthSession?.start()
                        
                    }) {
                        Text("Trigger 2FA (SMS)")
                    }
                }

                let loginButton = Button(action: {
                    let context = ASWebAuthSessionContextProvider()
                    asWebAuthSession = client.getLoginSession(contextProvider: context,
                                                              withSSO: true,
                                                              completion: handleResult)
                    asWebAuthSession?.start()
                }) {
                    Text("Login")
                }

                loginButton.onOpenURL { url in
                    client.handleAuthenticationResponse(url: url) { result in
                        DispatchQueue.main.async {
                            asWebAuthSession?.cancel()
                        }

                        handleResult(result)
                    }
                }
               
                Spacer().frame(height: 50)
                
                Button(action: {
                    self.user?.fetchProfileData { result in
                        switch result {
                        case .success(let userData):
                            print(userData)
                        case .failure(.unexpectedError(LoginStateError.notLoggedIn)):
                            print("User was logged-out")
                            self.user = nil
                        case .failure(let error):
                            print(error)
                        }
                    }
                }) {
                    Text("Fetch profile data")
                }.disabled(!userIsLoggedIn)
                
                Button(action: {
                    self.user?.webSessionURL(clientId: "5bcdd51bfba0cc7427315112", redirectURI: "http://zoopermarket.com/safepage") { result in
                        switch result {
                        case .success(let sessionUrl):
                            print(sessionUrl)
                        case .failure(let error):
                            print(error)
                        }
                    }
                }) {
                    Text("Start session exchange")
                }.disabled(!userIsLoggedIn)

                Button(action: {
                    accountPagesURL = self.clientConfiguration.accountPagesURL
                    showAccountPages = true
                }) {
                    Text("Show account pages")
                }.disabled(!userIsLoggedIn)
                
                Button(action: {
                    self.user?.logout()
                    self.user = nil
                    print("Logged out")
                }) {
                    Text("Logout")
                }.disabled(!userIsLoggedIn)
                NavigationLink("", destination: webView, isActive: $showAccountPages)
            }
        }
    }
    
    func handleResult(_ result: Result<User, LoginError>) {
        switch result {
        case .success(let user):
            print("Success - logged in as \(user.uuid ?? "")")
            self.user = user
        case .failure(let error):
            print(error)
            
        }
    }
}


struct WebView : UIViewRepresentable {
    @Binding var url: URL?
    
    func makeUIView(context: Context) -> WKWebView  {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let u = url {
            uiView.load(URLRequest(url: u))
        }
    }
}

class MyUserDelegate: UserDelegate {
    var onLogout: (() -> Void)?
    
    // MARK: UserDelegate
    
    func userDidLogout() {
        onLogout?()
    }
}
