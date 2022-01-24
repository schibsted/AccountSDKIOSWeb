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
        view.spacing = isPhone ? 15 : 0
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
    
    override var shouldAutorotate: Bool {
        (isPhone && UIDevice.current.orientation != .portrait) ? false : true
    }

    override open var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation{
        get {
            .portrait
        }
    }

    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        get {
            .portrait
        }
    }
    
    private var mainView: UIView?
    private var originalTransform: CGAffineTransform?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation != .portrait {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = isPhone ? .black.withAlphaComponent(0.6) : .white
        
        if isPhone {
            let y = (UIDevice.current.orientation == .portrait) ? UIScreen.main.bounds.height - 570 : 300
            mainView = UIView(frame: CGRect(x: 0, y: y, width: UIScreen.main.bounds.width, height: 570))

            originalTransform = mainView?.transform
            if let mainView = mainView {
                mainView.layer.cornerRadius = 10
                mainView.backgroundColor = .white
                mainView.addSubview(userInformationView)
                mainView.addSubview(primaryButton)
                mainView.addSubview(linksView)
                mainView.addSubview(footerStackView)
                view.addSubview(mainView)
                
                let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(sender:)))
                mainView.addGestureRecognizer(panGestureRecognizer)
            }
        } else {
            view.addSubview(userInformationView)
            view.addSubview(primaryButton)
            view.addSubview(linksView)
            view.addSubview(footerStackView)
        }
        
        primaryButton.addTarget(self, action: #selector(SimplifiedLoginViewController.primaryButtonClicked), for: .touchUpInside)
        linksView.loginWithDifferentAccountButton.addTarget(self, action: #selector(SimplifiedLoginViewController.loginWithDifferentAccountClicked), for: .touchUpInside)
        linksView.continueWithoutLoginButton.addTarget(self, action: #selector(SimplifiedLoginViewController.continueWithoutLoginClicked), for: .touchUpInside)
        footerStackView.privacyURLButton.addTarget(self, action: #selector(SimplifiedLoginViewController.privacyPolicyClicked), for: .touchUpInside)
        
        if isPhone {
            setupConstraints()
            //setupNavigationBar()
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
            navigationBarAppearance.titleTextAttributes =
            [NSAttributedString.Key.foregroundColor: UIColor.black]
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
        
        let buttonWidth = primaryButton.widthAnchor.constraint(equalToConstant: 343)
        buttonWidth.priority = .defaultLow
        let buttonLead = primaryButton.leadingAnchor.constraint(equalTo: margin.leadingAnchor)
        let buttonTrail = primaryButton.trailingAnchor.constraint(equalTo: margin.trailingAnchor)
        let allConstraints =  userInformationView.internalConstraints + footerStackView.internalConstraints + [
            // UserInformation
            userInformationView.leadingAnchor.constraint(equalTo: margin.leadingAnchor),
            userInformationView.trailingAnchor.constraint(equalTo: margin.trailingAnchor),
            userInformationView.topAnchor.constraint(lessThanOrEqualTo: mainView!.topAnchor, constant: 20),
            
            // Primary button
            primaryButton.topAnchor.constraint(lessThanOrEqualTo: userInformationView.bottomAnchor, constant: 45),
            primaryButton.centerXAnchor.constraint(equalTo: userInformationView.centerXAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 48),
            buttonWidth,
            buttonLead,
            buttonTrail,
            // Links View
            linksView.topAnchor.constraint(lessThanOrEqualTo: primaryButton.bottomAnchor, constant: 10),
            linksView.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),

            // Footer
            footerStackView.leadingAnchor.constraint(equalTo: margin.leadingAnchor),
            footerStackView.trailingAnchor.constraint(equalTo: margin.trailingAnchor),
            footerStackView.bottomAnchor.constraint(equalTo: mainView!.bottomAnchor, constant: -20),
        ]
        
        NSLayoutConstraint.activate(allConstraints)
    }
    
    func setupiPadConstraints() {
        
        let margin = view.layoutMarginsGuide
        let allConstraints =  userInformationView.internalConstraints + footerStackView.internalConstraints + [
            // UserInformation
            userInformationView.leadingAnchor.constraint(equalTo: margin.leadingAnchor),
            userInformationView.trailingAnchor.constraint(equalTo: margin.trailingAnchor),
            userInformationView.topAnchor.constraint(equalTo: view.topAnchor, constant: -30),
            
            // Primary button
            primaryButton.topAnchor.constraint(equalTo: userInformationView.bottomAnchor, constant: 10),
            primaryButton.centerXAnchor.constraint(equalTo: userInformationView.centerXAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 48),
            primaryButton.widthAnchor.constraint(equalToConstant: 343),
            
            // Links View
            linksView.topAnchor.constraint(lessThanOrEqualTo: primaryButton.bottomAnchor, constant: 10),
            linksView.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            
            // Footer
            footerStackView.centerXAnchor.constraint(equalTo: userInformationView.centerXAnchor),
            footerStackView.heightAnchor.constraint(equalToConstant: 156),
            footerStackView.widthAnchor.constraint(equalToConstant: 394),
            footerStackView.bottomAnchor.constraint(equalTo: margin.bottomAnchor, constant: -30),
        ]
        NSLayoutConstraint.activate(allConstraints)
    }
    
    @objc private func didPan(sender: UIPanGestureRecognizer) {
        guard let mainView = mainView else {
            return
        }
        
        if sender.state == .ended {
            let location = sender.location(in: view)
            if location.y >= 0.7 * UIScreen.main.bounds.height {
                UIView.animate(withDuration: 0.3) {
                    self.view.backgroundColor = .clear
                }
                self.dismiss(animated: true, completion: nil)
            } else {
                UIView.animate(withDuration: 0.3) {
                    mainView.transform = self.originalTransform!
                    sender.setTranslation(.zero, in: mainView)
                }
            }
        }
        
        let translation = sender.translation(in: view)
        
        guard translation.y > 0 else {
            return
        }
        
        mainView.transform = mainView.transform.translatedBy(x: .zero, y: translation.y)
        sender.setTranslation(.zero, in: mainView)
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

extension UINavigationController { //probably its better to subclass
    
    override open var shouldAutorotate: Bool {
        get {
            if let visibleVC = visibleViewController {
                return visibleVC.shouldAutorotate
            }
            return super.shouldAutorotate
        }
    }
    
    override open var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation{
        get {
            if let visibleVC = visibleViewController {
                return visibleVC.preferredInterfaceOrientationForPresentation
            }
            return super.preferredInterfaceOrientationForPresentation
        }
    }
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        get {
            if let visibleVC = visibleViewController {
                return visibleVC.supportedInterfaceOrientations
            }
            return super.supportedInterfaceOrientations
        }
    }
}
