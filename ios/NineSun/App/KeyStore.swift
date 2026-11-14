import Foundation
import Security

/// 金鑰存在 iPhone 的鑰匙圈（Keychain）：只在這支手機上，不會上傳、也不會進備份到別的裝置
enum KeyStore {
    private static func base(_ name: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "ninesun",
         kSecAttrAccount as String: name]
    }

    static func get(_ name: String) -> String {
        var q = base(name)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return "" }
        return String(data: d, encoding: .utf8) ?? ""
    }

    static func set(_ name: String, _ value: String) {
        SecItemDelete(base(name) as CFDictionary)
        guard !value.isEmpty else { return }
        var add = base(name)
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
