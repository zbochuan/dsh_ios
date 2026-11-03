import Foundation
import Security

public enum CredentialStoreError: Error, Sendable, Equatable, LocalizedError {
    case keychain(OSStatus)
    case invalidStoredData
    case identityMismatch

    public var errorDescription: String? {
        switch self {
        case .keychain(let status): "Secure storage could not be accessed (Keychain status \(status))."
        case .invalidStoredData: "The saved Remote identity could not be read. Remove it explicitly before creating a new identity."
        case .identityMismatch: "These Remote credentials do not belong to the saved device identity."
        }
    }
}

/// Stores one atomic identity-and-device-token record per normalized server origin.
/// Only Remote credentials are persisted. Passwords and account registration tokens remain transient.
public actor CredentialStore {
    private let storage: any CredentialStorage

    public init(service: String = "app.dsh.remote.credentials.v1") {
        storage = KeychainCredentialStorage(service: service)
    }

    init(storage: any CredentialStorage) { self.storage = storage }

    public func identity(for server: RemoteServerURL) throws -> DeviceIdentity? {
        try read(server)?.identity
    }

    public func loadOrCreateIdentity(for server: RemoteServerURL, name: String) throws -> DeviceIdentity {
        if let existing = try read(server) { return existing.identity }
        let identity = try DeviceIdentity.generate(name: name)
        try write(Record(identity: identity, credentials: nil), for: server)
        return identity
    }

    public func credentials(for server: RemoteServerURL, deviceID: String) throws -> DeviceTokenPair? {
        guard let record = try read(server), record.identity.deviceId == deviceID else { return nil }
        return record.credentials
    }

    /// Call after registration and after every successful refresh, which rotates the token pair.
    public func saveCredentials(_ credentials: DeviceTokenPair, for server: RemoteServerURL,
                                deviceID: String) throws {
        guard var record = try read(server), record.identity.deviceId == deviceID else {
            throw CredentialStoreError.identityMismatch
        }
        record.credentials = credentials
        try write(record, for: server)
    }

    /// Local sign-out preserves the identity for future registration. It does not revoke server tokens.
    public func clearCredentials(for server: RemoteServerURL, deviceID: String) throws {
        guard var record = try read(server) else { return }
        guard record.identity.deviceId == deviceID else { throw CredentialStoreError.identityMismatch }
        record.credentials = nil
        try write(record, for: server)
    }

    /// Explicitly forget this server's identity and credentials together.
    public func removeIdentity(for server: RemoteServerURL) throws {
        try storage.remove(key: key(for: server))
    }

    private func key(for server: RemoteServerURL) -> String { "remote-v1|\(server.description)" }

    private func read(_ server: RemoteServerURL) throws -> Record? {
        guard let data = try storage.load(key: key(for: server)) else { return nil }
        do { return try JSONDecoder().decode(Record.self, from: data) }
        catch { throw CredentialStoreError.invalidStoredData }
    }

    private func write(_ record: Record, for server: RemoteServerURL) throws {
        try storage.save(JSONEncoder().encode(record), key: key(for: server))
    }

    private struct Record: Codable {
        let identity: DeviceIdentity
        var credentials: DeviceTokenPair?
    }
}

/// A synchronous backend keeps each actor operation atomic across read/update/write.
protocol CredentialStorage: Sendable {
    func load(key: String) throws -> Data?
    func save(_ data: Data, key: String) throws
    func remove(key: String) throws
}

private struct KeychainCredentialStorage: CredentialStorage {
    let service: String

    private func query(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: false,
        ]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    func load(key: String) throws -> Data? {
        var query = query(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialStoreError.keychain(status) }
        guard let data = result as? Data else { throw CredentialStoreError.invalidStoredData }
        return data
    }

    func save(_ data: Data, key: String) throws {
        let query = query(key: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw CredentialStoreError.keychain(status) }
        let item = query.merging(attributes) { _, new in new }
        let insertStatus = SecItemAdd(item as CFDictionary, nil)
        guard insertStatus == errSecSuccess else { throw CredentialStoreError.keychain(insertStatus) }
    }

    func remove(key: String) throws {
        let status = SecItemDelete(query(key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }
}
