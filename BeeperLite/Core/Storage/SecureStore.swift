import Foundation
import Security

enum SecureStoreError: Error {
    case duplicateItem
    case itemNotFound
    case unhandledError(status: OSStatus)
}

final class SecureStore {
    static let shared = SecureStore()
    private init() {}
    
    /// Sauvegarde de l'Access Token (ou autre string) dans le Keychain
    func save(token: String, for account: String) throws {
        let tokenData = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Le token existe déjà, on le met à jour
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account
            ]
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: tokenData
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            if updateStatus != errSecSuccess {
                throw SecureStoreError.unhandledError(status: updateStatus)
            }
        } else if status != errSecSuccess {
            throw SecureStoreError.unhandledError(status: status)
        }
    }
    
    /// Récupération du token
    func getToken(for account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw SecureStoreError.unhandledError(status: status)
        }
    }
    
    /// Suppression du token (ex: lors d'un logout)
    func deleteToken(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw SecureStoreError.unhandledError(status: status)
        }
    }
}
