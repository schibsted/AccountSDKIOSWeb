//
//  ContentView.swift
//  AnotherSharedKeychainApp
//
//  Created by Daniel Echegaray on 2021-11-21.
//

import SwiftUI
import AccountSDKIOSWeb

struct ContentView: View {
    static let config = ClientConfiguration(environment: .pre,
                                            clientId:"App TWO ID",
                                            redirectURI: URL(string: "com.sdk-example.pre.602504e1b41fa31789a95aa7:/login")!)
                                            
    static let client: Client =  Client(configuration: ContentView.config)

    var body: some View {
        Text("Hello, world!")
            .padding()
        
        VStack(spacing: 50) {
            VStack(spacing: 20) {
                Button(action: fetchFromSharedKeychain, label: { Text("fetch from Shared keychain") } )
                Button(action: storeToSharedKeychain, label: { Text("Store To Shared keychain") } )
            }
        }
    }
    
    func storeToSharedKeychain() {
        let myAccessGroup = "GS8T83EM2X.com.testing.SharingExample"
        let manager = SimplifiedLoginManager(accessGroup: myAccessGroup, client: ContentView.client, env: .pre, withMFA: .password, loginHint: nil, extraScopeValues: [], withSSO: true, completion: handleResult)
        manager.storeInSharedKeychain(clientId: "AppOne", aStringValue: "THIS IS APP ONE STORING :D") { result in
            switch result {
            case .success:
                print("Stored to SHARED KEYCHAIN. BOOYA!")
            case .failure(let error):
                print("FAILED TO STORE, error: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchFromSharedKeychain() {
        let myAccessGroup = "GS8T83EM2X.com.testing.SharingExample"
        let manager = SimplifiedLoginManager(accessGroup: myAccessGroup, client: ContentView.client, env: .pre, withMFA: .password, loginHint: nil, extraScopeValues: [], withSSO: true, completion: handleResult)
        do {
            try manager.getSimplifiedLogin { result in
                switch result {
                case .success(let simplifiedLoginViewController):
                    print("Success I got the viewController: \(simplifiedLoginViewController) ")
                case .failure(let error):
                    print(error)
                }
            }
        } catch  {
            print(error)
        }
    }
    
    func handleResult(_ result: Result<User, LoginError>) {
        switch result {
        case .success(let user):
            print("Success - logged in as \(user.uuid ?? "")")
        case .failure(let error):
            print(error)
            
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
