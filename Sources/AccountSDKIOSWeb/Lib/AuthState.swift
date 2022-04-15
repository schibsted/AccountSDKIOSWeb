import Foundation
import CommonCrypto

internal struct AuthState: Codable {
    let state: String
    let nonce: String
    let codeVerifier: String
    let mfa: MFAType?

    func codeChallengeMethod() -> String {
        return "S256"
    }

    func makeCodeChallenge () -> String {
        return computeCodeChallenge(from: codeVerifier)
    }

}

extension AuthState {

    init(mfa: MFAType?) {

        let state = randomString(length: 10)
        let nonce = randomString(length: 10)
        let codeVerifier = randomString(length: 60)

        self.init(state: state, nonce: nonce, codeVerifier: codeVerifier, mfa: mfa)
    }
}

private func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in letters.randomElement()! })
}

private func computeCodeChallenge(from codeVerifier: String) -> String {
    func base64url(data: Data) -> String {
        let base64url = data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }

    func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }

    return base64url(data: sha256(data: Data(codeVerifier.utf8)))
}
