//
//  KeychainManager.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 09..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation
import Security

final class KeychainManager {
    
    struct Credentials {
        var account: String
        var secret: String
    }
    
    @discardableResult
    func setCredentials(_ credentials: Credentials, forService service: String, label: String? = nil) -> Bool {
        let secretData = credentials.secret.data(using: .utf8)!
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        
        if let label = label {
            query[kSecAttrLabel as String] = label
        }
        
        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecItemNotFound {
//            query = [
//                kSecClass as String: kSecClassGenericPassword,
//                kSecAttrAccount as String: credentials.account,
//                kSecValueData as String: secretData,
//                kSecAttrLabel as String: label,
//                kSecAttrService as String: service
//            ]
            status = SecItemAdd(query as CFDictionary, nil)
        }
        else {
            let attributes: [String: Any] = [
                kSecAttrAccount as String: credentials.account,
                kSecValueData as String: secretData
            ]
            status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        }
        
        return status == errSecSuccess
    }
    
    func credentials(forService service: String) -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard
            status == errSecSuccess,
            let existingItem = item as? [String: Any],
            let secretData = existingItem[kSecValueData as String] as? Data,
            let secret = String(data: secretData, encoding: .utf8),
            let account = existingItem[kSecAttrAccount as String] as? String
        else {
            return nil
        }
        
        return Credentials(account: account, secret: secret)
    }
    
}
