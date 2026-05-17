#if canImport(Security)
import Foundation
import Security

public final class KeychainStore: KeychainStoring {

    private let service: String

    public init(service: String = "com.sweep.app") {
        self.service = service
    }

    // MARK: - KeychainStoring

    @discardableResult
    public func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            SweepLogger.storage.error("KeychainStore.save: failed to encode value for key '\(key, privacy: .public)'")
            return false
        }

        // Check whether the item already exists.
        let query = baseQuery(for: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            // Item exists — update it.
            let attributes: [CFString: Any] = [
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                SweepLogger.storage.error("KeychainStore.save: SecItemUpdate failed for key '\(key, privacy: .public)' status=\(updateStatus)")
                return false
            }
            SweepLogger.storage.debug("KeychainStore.save: updated key '\(key, privacy: .public)'")
            return true

        case errSecItemNotFound:
            // Item does not exist — add it.
            var addQuery = baseQuery(for: key)
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                SweepLogger.storage.error("KeychainStore.save: SecItemAdd failed for key '\(key, privacy: .public)' status=\(addStatus)")
                return false
            }
            SweepLogger.storage.debug("KeychainStore.save: added key '\(key, privacy: .public)'")
            return true

        default:
            SweepLogger.storage.error("KeychainStore.save: SecItemCopyMatching failed for key '\(key, privacy: .public)' status=\(status)")
            return false
        }
    }

    public func load(key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                SweepLogger.storage.error("KeychainStore.load: SecItemCopyMatching failed for key '\(key, privacy: .public)' status=\(status)")
            }
            return nil
        }

        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            SweepLogger.storage.error("KeychainStore.load: failed to decode data for key '\(key, privacy: .public)'")
            return nil
        }

        SweepLogger.storage.debug("KeychainStore.load: loaded key '\(key, privacy: .public)'")
        return string
    }

    public func delete(key: String) {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            SweepLogger.storage.error("KeychainStore.delete: SecItemDelete failed for key '\(key, privacy: .public)' status=\(status)")
        } else {
            SweepLogger.storage.debug("KeychainStore.delete: deleted key '\(key, privacy: .public)'")
        }
    }

    // MARK: - Private helpers

    private func baseQuery(for key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
    }
}
#endif
