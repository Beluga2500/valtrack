import Foundation
import Security

enum KeychainStore {
    static func save(_ data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct RiotSession: Codable {
    var accessToken: String
    var idToken: String
    var entitlementToken: String
    var puuid: String
    var region: String   // ex: "eu"
    var shard: String    // ex: "eu"
    var gameName: String
    var tagLine: String
}

enum SessionManager {
    private static let key = "valoshop.session"

    static func save(_ session: RiotSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        KeychainStore.save(data, key: key)
    }

    static func load() -> RiotSession? {
        guard let data = KeychainStore.load(key: key) else { return nil }
        return try? JSONDecoder().decode(RiotSession.self, from: data)
    }

    static func clear() {
        KeychainStore.delete(key: key)
    }
}
