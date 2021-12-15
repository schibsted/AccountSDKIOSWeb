import AuthenticationServices
import SwiftUI
import UIKit

class SimplifiedLoginViewController: UIViewController {
    
    private var viewModel: SimplifiedLoginViewModel
    private let isPhone: Bool = UIDevice.current.userInterfaceIdiom == .phone
    
    private lazy var userInformationView: UserInformationView = {
        let view = UserInformationView(viewModel: viewModel)
        view.alignment = .center
        view.axis = .vertical
        view.distribution = .fill
        view.spacing = 8
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false

        view.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    // MARK: Primary button
    
    private lazy var primaryButton: UIButton = {
        let button = UIButton()
        let title = "\(viewModel.localizationModel.continuAsButtonTitle) \(viewModel.displayName)"
        
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.backgroundColor = .black
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()
    
    // MARK: Links
    
    private lazy var linksView: LinksView = {
        let view = LinksView(viewModel: viewModel)
        view.alignment = .center
        view.axis = .vertical
        view.distribution = .fill
        view.spacing = isPhone ? 20 : 0
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false

        view.layoutMargins = UIEdgeInsets(top: isPhone ? 8 : 0, left: 0, bottom: 16, right: 0)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    // MARK: Footer
    
    private lazy var footerStackView: FooterView = {
        let view = FooterView(viewModel: viewModel)
        view.alignment = .center
        view.axis = .vertical
        view.distribution = .fill
        view.spacing = 12
        view.layer.cornerRadius = 12
        
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 249/255, green: 249/255, blue: 250/255, alpha: 1)
        
        view.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Main view
        view.addSubview(userInformationView)
        view.addSubview(primaryButton)
        view.addSubview(linksView)
        view.addSubview(footerStackView)
        
        primaryButton.addTarget(self, action: #selector(SimplifiedLoginViewController.primaryButtonClicked), for: .touchUpInside)
        linksView.loginWithDifferentAccountButton.addTarget(self, action: #selector(SimplifiedLoginViewController.loginWithDifferentAccountClicked), for: .touchUpInside)
        linksView.continueWithoutLoginButton.addTarget(self, action: #selector(SimplifiedLoginViewController.continueWithoutLoginClicked), for: .touchUpInside)
        footerStackView.privacyURLButton.addTarget(self, action: #selector(SimplifiedLoginViewController.privacyPolicyClicked), for: .touchUpInside)
        
        if isPhone {
            setupConstraints()
            setupNavigationBar()
        } else {
            setupiPadConstraints()
        }
    }
    
    func setupNavigationBar(){
        guard isPhone else {
            return
        }
        
        let navigationBar = navigationController?.navigationBar
        navigationBar?.topItem?.title = viewModel.localizationModel.continueToLogIn
        
        if #available(iOS 13.0, *) {
            
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.shadowColor = .gray
            navigationBarAppearance.backgroundColor = .white
            navigationBar?.scrollEdgeAppearance = navigationBarAppearance
        }  else {
            navigationBar?.barTintColor = .white
        }
    }
    
    init(viewModel: SimplifiedLoginViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupConstraints() {
        
        let margin = view.layoutMarginsGuide
        let allConstraints =  userInformationView.internalConstraints + footerStackView.internalConstraints + [
            // UserInformation
            userInformationView.leadingAnchor.constraint(equalTo: margin.leadingAnchor),
            userInformationView.trailingAnchor.constraint(equalTo: margin.trailingAnchor),
            userInformationView.topAnchor.constraint(lessThanOrEqualTo: margin.topAnchor, constant: 57),
            
            // Primary button
            primaryButton.topAnchor.constraint(lessThanOrEqualTo: userInformationView.bottomAnchor, constant: 45),
            primaryButton.centerXAnchor.constraint(equalTo: userInformationView.centerXAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 48),
            primaryButton.widthAnchor.constraint(equalToConstant: 343),
            
            // Links View
            linksView.topAnchor.constraint(lessThanOrEqualTo: primaryButton.bottomAnchor, constant: 53),
            linksView.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            
            // Footer
            footerStackView.leadingAnchor.constraint(equalTo: margin.leadingAnchor),
            footerStackView.trailingAnchor.constraint(equalTo: margin.trailingAnchor),
            footerStackView.bottomAnchor.constraint(equalTo: margin.bottomAnchor),

        ]
        
        NSLayoutConstraint.activate(allConstraints)
    }
    
    func setupiPadConstraints() {
        
        let margin = view.layoutMarginsGuide
        let allConstraints =  userInformationView.internalConstraints + footerStackView.internalConstraints + [
            // UserInformation
            userInformationView.leadingAnchor.constraint(equalTo: margin.leadingAnchor),
            userInformationView.trailingAnchor.constraint(equalTo: margin.trailingAnchor),
            userInformationView.topAnchor.constraint(equalTo: margin.topAnchor, constant: -90),

            // Primary button
            primaryButton.topAnchor.constraint(equalTo: userInformationView.bottomAnchor, constant: 10),
            primaryButton.centerXAnchor.constraint(equalTo: userInformationView.centerXAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 48),
            primaryButton.widthAnchor.constraint(equalToConstant: 343),
            
            // Links View
            linksView.topAnchor.constraint(lessThanOrEqualTo: primaryButton.bottomAnchor, constant: 20),
            linksView.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            
            // Footer
            footerStackView.centerXAnchor.constraint(equalTo: userInformationView.centerXAnchor),
            footerStackView.heightAnchor.constraint(equalToConstant: 156),
            footerStackView.widthAnchor.constraint(equalToConstant: 394),
            footerStackView.bottomAnchor.constraint(equalTo: margin.bottomAnchor, constant: -30),
        ]
        NSLayoutConstraint.activate(allConstraints)
    }
}

extension SimplifiedLoginViewController {
    
    @objc func primaryButtonClicked() { viewModel.send(action: .clickedContinueAsUser) }
    @objc func loginWithDifferentAccountClicked() { viewModel.send(action: .clickedLoginWithDifferentAccount) }
    @objc func continueWithoutLoginClicked() { viewModel.send(action: .clickedContinueWithoutLogin) }
    @objc func privacyPolicyClicked() { viewModel.send(action: .clickedClickPrivacyPolicy) }
    
    enum UserAction {
        case clickedContinueAsUser
        case clickedLoginWithDifferentAccount
        case clickedContinueWithoutLogin
        case clickedClickPrivacyPolicy
    }
}

#if DEBUG
@available(iOS 13.0.0, *)
struct SimplifiedLoginViewController_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SimplifiedLoginViewControllerRepresentable()
        }
    }
}

@available(iOS 13.0.0, *)
public struct SimplifiedLoginViewControllerRepresentable: UIViewControllerRepresentable {
    public init(){}
    @State var asWebAuthenticationSession: ASWebAuthenticationSession?
    
    public func makeUIViewController(context: Context) -> UINavigationController {
        let clientRedirectURI = URL(string: "com.sdk-example.pre.602504e1b41fa31789a95aa7:/login")!
        let clientConfiguration = ClientConfiguration(environment: .pre,
                                                      clientId: "602504e1b41fa31789a95aa7",
                                                      redirectURI: clientRedirectURI)
        let client = Client(configuration: clientConfiguration)
        
        let completion: LoginResultHandler = { result in
            switch result {
            case .success(let user):
                print("Success - logged in as \(user.uuid ?? ""), tokens: \(user.tokens?.description ?? "")")
                
            case .failure(let error):
                print(error)
            }
        }
        
        let clientName = (Bundle.applicationName() != nil) ? Bundle.applicationName()! : "not_configured"
        let userContext = UserContextFromTokenResponse(identifier: "Demo identifier", display_text: "Display.Text", client_name: "demo client name")
        let userProfileResponse = UserProfileResponse(uuid: "", userId: "", status: nil, email: "demo@email.com", emailVerified: nil, emails: nil, phoneNumber: nil, phoneNumberVerified: nil, phoneNumbers: nil, displayName: "display.name", name: Name(givenName: "firstName", familyName: "lastName", formatted: nil), addresses: nil, gender: nil, birthday: nil, accounts: nil, merchants: nil, published: nil, verified: nil, updated: nil, passwordChanged: nil, lastAuthenticated: nil, lastLoggedIn: nil, locale: nil, utcOffset: nil)
        
        
        let clientConfig = ClientConfiguration(env: .pre, serverURL: URL(string: "https://issuer.example.com")!, sessionServiceURL: URL(string: "https://another.issuer.example.com")!, clientId: "client1", redirectURI: URL(string: "com.example.client1://login")!)
        let idTokenClaims = IdTokenClaims(iss: clientConfig.issuer, sub: "userUuid", userId: "12345", aud: ["client1"], exp: Date().timeIntervalSince1970 + 3600, nonce: "testNonce", amr: nil)
        let userTokens = UserTokens(accessToken: "accessToken", refreshToken: "refreshToken", idToken: "idToken", idTokenClaims: idTokenClaims)
        let user = User(client: Client(configuration: clientConfig, httpClient: nil), tokens: userTokens)
        let fetcher = SimplifiedLoginFetcher(user: user)
        let context = ASWebAuthSessionContextProvider()
        let s = SimplifiedLoginUIFactory.buildViewController(client: client, contextProvider: context ,assertionFetcher: fetcher, userContext: userContext, userProfileResponse: userProfileResponse, clientName: clientName, withMFA: .password, loginHint: nil, extraScopeValues: [], withSSO: true, completion: completion) as! UINavigationController
        
        return s
    }
    
    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
    
    public typealias UIViewControllerType = UINavigationController
}

#endif

