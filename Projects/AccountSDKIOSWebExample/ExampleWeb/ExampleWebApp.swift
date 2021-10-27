import SwiftUI
import AccountSDKIOSWeb

@main
struct ExampleWebApp: App {
    private let client: Client
    private let clientConfiguration: ClientConfiguration
    
    init() {
        let clientRedirectURI = URL(string: "com.sdk-example.pre.602504e1b41fa31789a95aa7:/login")!
        let clientConfiguration = ClientConfiguration(environment: .pre,
                                                      clientId: "602504e1b41fa31789a95aa7",
                                                      redirectURI: clientRedirectURI)
        
        self.client = Client(configuration: clientConfiguration)
        self.clientConfiguration = clientConfiguration
    }

    var body: some Scene {
        WindowGroup {
            ContentView(client: client, clientConfiguration: clientConfiguration)
        }
    }
}