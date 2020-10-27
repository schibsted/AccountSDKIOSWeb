import Foundation
import Security

class KeychainStorage {
    private let service: String

    init(forService: String) {
        self.service = forService
    }

    func addValue(_ value: Data, forAccount: String?) {
        // TODO delete possibly existing value first or create separate update function?

        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecValueData as String: value]
        forAccount.map { query[kSecAttrAccount as String] = $0 }
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecDuplicateItem || status == errSecSuccess else {
            fatalError("Unable to store the secret")
        }
    }

    func getValue(forAccount: String?) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true
        ]
        forAccount.map { query[kSecAttrAccount as String] = $0 }

        return get(query: query) as? Data
    }
    
    func getAll() -> [Data] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        let result = get(query: query) as! [Data?]
        return result.compactMap { $0 }
    }

    private func get(query: [String: Any]) -> AnyObject? {
        var extractedData: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &extractedData)
        
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            fatalError("Unable to fulfill the keychain query")
        }

        return extractedData
    }

    func removeValue(forAccount: String?) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        forAccount.map { query[kSecAttrAccount as String] = $0 }
        
        let result = SecItemDelete(query as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else {
            fatalError("Unable to delete the secret")
        }
    }
}
