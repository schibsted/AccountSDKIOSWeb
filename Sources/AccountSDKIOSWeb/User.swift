import Foundation

public class User: Equatable {
    private let clientId: String
    private let accessToken: String
    private let refreshToken: String?
    private let idToken: String
    private let idTokenClaims: IdTokenClaims
    
    public let uuid: String
    
    init(clientId: String, accessToken: String, refreshToken: String?, idToken: String, idTokenClaims: IdTokenClaims) {
        self.clientId = clientId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        
        self.idTokenClaims = idTokenClaims
        self.uuid = idTokenClaims.sub
    }

    func persist() {
        let toStore = StoredUserTokens(clientId: clientId, accessToken: accessToken, refreshToken: refreshToken, idToken: idToken, idTokenClaims: idTokenClaims)
        DefaultTokenStorage.store(toStore)
    }
    
    public func logout() {
        DefaultTokenStorage.remove(forClientId: clientId)
    }
    
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.uuid == rhs.uuid
            && lhs.clientId == rhs.clientId
            && lhs.accessToken == rhs.accessToken
            && lhs.refreshToken == rhs.refreshToken
            && lhs.idToken == rhs.idToken
            && lhs.idTokenClaims == rhs.idTokenClaims
    }
}
