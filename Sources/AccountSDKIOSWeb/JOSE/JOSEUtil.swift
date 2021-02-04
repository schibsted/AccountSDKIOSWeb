import Foundation
import JOSESwift

public enum SignatureValidationError: Error {
    case invalidJWS
    case unknownKeyId
    case noKeyId
    case unsupportedKeyType
    case unspecifiedAlgorithm
    case invalidSignature
}

internal extension JWK {
    func toSecKey() -> SecKey? {
        if let key = self as? RSAPublicKey,
           let converted = try? key.converted(to: SecKey.self) {
            return converted
        } else if let key = self as? ECPublicKey,
                  let converted = try? key.converted(to: SecKey.self) {
            return converted
        }

        return nil
    }
}

internal enum JOSEUtil {
    internal static func verifySignature(of serialisedJWS: String, withKeys jwks: JWKS, completion: @escaping (Result<Data, SignatureValidationError>) -> Void) {
        guard let jws = try? JWS(compactSerialization: serialisedJWS) else {
            completion(.failure(.invalidJWS))
            return
        }

        guard let keyId = jws.header.kid else {
            completion(.failure(.noKeyId))
            return
        }


        guard let algorithm = jws.header.algorithm else {
            completion(.failure(.unspecifiedAlgorithm))
            return
        }

        jwks.getKey(withId: keyId) { jwk in
            guard let key = jwk else {
                completion(.failure(.unknownKeyId))
                return
            }
            
            guard let publicKey = key.toSecKey(),
                let verifier = Verifier(verifyingAlgorithm: algorithm, publicKey: publicKey) else {
                completion(.failure(.unsupportedKeyType))
                return
            }

            do {
                let payload = try jws.validate(using: verifier).payload
                completion(.success(payload.data()))
            } catch {
                // TODO log error
                completion(.failure(.invalidSignature))
            }
        }
    }
}

